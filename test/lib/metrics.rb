
# max values used by cyberdojo/check-test-results image
# which is called from scripts/test_in_containers.sh

MAX = {
  failures:0,
  errors:0,
  warnings:0,
  skips:0,

  duration:10,

  app: {
    lines: {
       total:400,
      missed:0,
    },
    branches: {
       total:60,
      missed:0,
    }
  },

  test: {
    lines: {
       total:600,
      missed:0,
    },
    branches: {
       total:0,
      missed:0,
    }
  }
}
