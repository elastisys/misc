#!/usr/bin/env python
"""
A program that exercises a (pool of) ATC Node servers  by running a
"scaling scenario" against it. The scaling scenario is realized by
applying ATC testclient load according to a scheduled rate.

The scaling scenario is read from a file of ``(testclient rate, duration)``
tuples, describing the sequence of testclient request rates to apply
and the duration (in seconds) to apply each request rate.

A sample scenario file can, for example contain something similar to: ::

  # ========================================
  # Client rate (req/s) | Duration (seconds)
  # ========================================
  2   1800      
  4   1800     
  8   3600
  3   7200     
  11  3600 
  15  3600
  1   3600
  ...

In this example, the testclient will first be applied at rate 2 (req/s) for
1800 seconds before moving on to the next rate (4) for 1800 seconds, and so on.

"""
import argparse
import datetime
import logging
import re
from subprocess import Popen, STDOUT
import sys
import time
import urlparse

logging.basicConfig(level=logging.INFO,
                    format=("%(asctime)s [%(levelname)s] %(message)s"),
                    stream=sys.stdout)
log = logging.getLogger(__name__)


def apply_load(rate, duration, host, port):
    # arguments: <number of clients> <time interval between runs in seconds> <host> <port>
    num_clients = rate
    interval = 1
    # To achieve <rate>: run <rate> client process each at a rate of 1 requests every second
    testclient_cmd = ("java -jar /home/ubuntu/testclients/testclients.jar %d %d %s %d" %
                      (1, interval, host, port))
    log.info("running %dx: %s", num_clients, testclient_cmd)

    timestamp = datetime.datetime.now().strftime("%Y%m%d-%H:%M:%S")
    client_processes = []
    logfiles = []
    for client_num in range(num_clients):
        logfile = "testclient-%s-%d.log" % (timestamp, client_num)
        log.info("writing testclient%d log to: %s", client_num, logfile)
        logfile = open(logfile, "wb")
        process = Popen(testclient_cmd.split(), stderr=STDOUT, stdout=logfile)
        logfiles.append(logfile)
        client_processes.append(process)            
    time.sleep(duration)
    for process in client_processes:
        process.kill()
        logfile.close()


def parse_rate_schedule(rate_schedule_path):
    """Parses a rate schedule file and returns a list of
    :object:`(rate, duration)` tuples.

    Each non-empty/non-commented line in the file is expected to contain
    a space-separated :object:`<request-rate> <duration-in-seconds>` entry.

    :return: The rate schedule.
    :rtype: list of :object:`(rate, duration)` tuples.
    """
    rates = []
    with open(rate_schedule_path) as rate_schedule:
        for line in rate_schedule:
            if re.match(r'^\s*#.*', line):
                # comment
                continue
            if  re.match(r'^\S*$', line):
                # empty row
                continue
            match = re.match(r'\s*(\d+)\s+(\d+)', line)
            if not match:
                raise RuntimeError(
                    "illegal input row in rate schedule: '%s'" % line)
            rate, duration = match.group(1), match.group(2)
            rates.append((int(rate), float(duration)))
    return rates

def timestamp():
    return time.strftime("%Y-%m-%dT%H:%M:%S.%s")

if __name__ == "__main__":   
    parser = argparse.ArgumentParser(
        description='apply ATC testclient load according to a rate schedule')
    parser.add_argument(
        "host", metavar="<HOST>", help=("The Node Server ELB IP address/host "
                                        "to apply load to."))
    parser.add_argument(
        "rate_schedule", metavar="<rate-schedule>",
        help=("The rate schedule file to apply: a "
              "list of '<rate> <duration-in-seconds>' rows"))
    parser.add_argument(
        "--port", metavar="<PORT>", default=8810,
        help=("The Node Server port to apply load to. Default: 8810."))
    
    args = parser.parse_args()
    rate_schedule = parse_rate_schedule(args.rate_schedule)
    for (rate, duration) in rate_schedule:
        log.info("applying rate %d for %d second(s) against %s:%d", rate, duration, args.host, args.port)
        apply_load(rate, duration, args.host, args.port)
            
