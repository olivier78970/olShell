#!/usr/bin/env python3
"""Prints the CUPS print queue whenever it changes.

Usage: printers-watch.py

Asks CUPS (through pycups, which system-config-printer depends on) every
couple of seconds for the printers and the jobs not yet completed, and prints
one JSON line at start and after every change:
  {"jobs": [{"id", "name", "printer", "size", "state", "user"}],
   "printers": [{"name", "info", "state", "message"}], "error": ""}
`size` is in kilobytes; `state` is CUPS' job state (3 pending, 4 held,
5 printing, 6 stopped) or printer state (3 idle, 4 printing, 5 stopped).
`error` is "pycups" when the module is missing (the script then stops) and
"cups" while CUPS can't be reached (it keeps trying). Used by
services/Printers.qml.
"""
import json
import time

POLL = 2  # seconds between two looks at the queue
RETRY = 10  # seconds before trying CUPS again after it failed

JOB_ATTRIBUTES = ["job-id", "job-name", "job-printer-uri", "job-k-octets", "job-state", "job-originating-user-name"]


def emit(state):
    print(json.dumps(state), flush=True)


try:
    import cups
except ImportError:
    emit({"jobs": [], "printers": [], "error": "pycups"})
    raise SystemExit(0)


def read(connection):
    printers = connection.getPrinters()
    jobs = connection.getJobs(which_jobs="not-completed", requested_attributes=JOB_ATTRIBUTES)
    # CUPS keeps a job's name and owner private unless the request asks for
    # the user's own jobs, so those come from a second request.
    for job_id, job in connection.getJobs(which_jobs="not-completed", my_jobs=True, requested_attributes=JOB_ATTRIBUTES).items():
        jobs.setdefault(job_id, {}).update(job)
    return {
        "jobs": [{
            "id": job_id,
            "name": job.get("job-name", ""),
            "printer": job.get("job-printer-uri", "").rsplit("/", 1)[-1],
            "size": job.get("job-k-octets", 0),
            "state": job.get("job-state", 3),
            "user": job.get("job-originating-user-name", ""),
        } for job_id, job in sorted(jobs.items())],
        "printers": [{
            "name": name,
            "info": printer.get("printer-info") or name,
            "state": printer.get("printer-state", 3),
            "message": printer.get("printer-state-message", ""),
        } for name, printer in sorted(printers.items())],
        "error": "",
    }


last = None
connection = None
while True:
    try:
        if connection is None:
            connection = cups.Connection()
        state = read(connection)
        delay = POLL
    except (RuntimeError, cups.IPPError, cups.HTTPError):
        # CUPS is down or restarting: connect afresh next time.
        connection = None
        state = {"jobs": [], "printers": [], "error": "cups"}
        delay = RETRY
    if state != last:
        last = state
        emit(state)
    time.sleep(delay)
