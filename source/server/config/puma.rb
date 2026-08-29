#!/usr/bin/env puma

environment 'production'
rackup "#{__dir__}/config.ru"

# A test-run waits on the docker daemon, runner computes ~nothing itself:
# the tar and gzip of a typical test-run payload cost under a millisecond.
# The Ruby MRI releases the GVL for docker daemon wait, so threads and
# process serve test-run requests equally well. Throughput has been measured
# both ways in docs/pre-started-container-pool.md and does not change.
#
# However, threads and processes are NOT equally effective for the pool of
# spare, cached containers; it effectiveness decreases with more workers
# because that increases the chance of a cache miss which would have been a
# hit on a different worker. So we go with less workers.
#
# We are conservative with threads. Consider what happens when 64 learners
# press [test] at the same time, on 4 cores, under 8 vs 64 threads.
#┌─────────────────────────┬───────────────────────┬──────────────────────────┐
#│          step           │        8 threads      │         64 threads       │
#├─────────────────────────┼───────────────────────┼──────────────────────────┤
#│ accepted at once        │ 8                     │ 64                       │
#├─────────────────────────┼───────────────────────┼──────────────────────────┤
#│ kata containers running │ 8                     │ 64                       │
#├─────────────────────────┼───────────────────────┼──────────────────────────┤
#│ CPU each gets           │ 1/2 core              │ 1/16 core                │
#├─────────────────────────┼───────────────────────┼──────────────────────────┤
#│ 2s test run takes       │ 4s                    │ 32s                      │
#├─────────────────────────┼───────────────────────┼──────────────────────────┤
#│ against max_seconds=10  │ Red|Amber|Green       │ times out                │
#├─────────────────────────┼───────────────────────┼──────────────────────────┤
#│ the other 56            │ queued but get a RAG  │ all running, all failing │
#├─────────────────────────┼───────────────────────┼──────────────────────────┤
#│ container held for      │ 4s                    │ the full 10s             │
#├─────────────────────────┼───────────────────────┼──────────────────────────┤
#│ learner's next move     │ reads the result      │ presses again            │
#└─────────────────────────┴───────────────────────┴──────────────────────────┘

workers(2)
threads(8, 8)
