
module Test
  module Data
    module PythonPytest

    IMAGE_NAME = 'cyberdojofoundation/python_pytest'

    # - - - - - - - - - - - - - - - - - - - - - - - -

    STDOUT_RED =
      <<~STDOUT_RED
      ============================= test session starts ==============================
      platform linux -- Python 3.6.5, pytest-3.6.2, py-1.5.3, pluggy-0.6.0
      rootdir: /tmp/sandbox, inifile:
      collected 1 item

      test_hiker.py F                                                          [100%]

      =================================== FAILURES ===================================
      ____________________ test_life_the_universe_and_everything _____________________

          def test_life_the_universe_and_everything():
              '''a simple example to start you off'''
              douglas = hiker.Hiker()
      >       assert douglas.answer() == 42
      E       assert 54 == 42
      E        +  where 54 = <bound method Hiker.answer of <hiker.Hiker object at 0x7f866f878f28>>()
      E        +    where <bound method Hiker.answer of <hiker.Hiker object at 0x7f866f878f28>> = <hiker.Hiker object at 0x7f866f878f28>.answer

      test_hiker.py:6: AssertionError
      =========================== 1 failed in 0.04 seconds ===========================
      STDOUT_RED

      # - - - - - - - - - - - - - - - - - - - - - - - -

      STDOUT_AMBER =
        <<~STDOUT_AMBER
        ============================= test session starts ==============================
        platform linux -- Python 3.6.5, pytest-3.6.2, py-1.5.3, pluggy-0.6.0
        rootdir: /tmp/sandbox, inifile:
        collected 0 items / 1 errors

        ==================================== ERRORS ====================================
        ________________________ ERROR collecting test_hiker.py ________________________
        /usr/local/lib/python3.6/site-packages/_pytest/python.py:468: in _importtestmodule
            mod = self.fspath.pyimport(ensuresyspath=importmode)
        /usr/local/lib/python3.6/site-packages/py/_path/local.py:668: in pyimport
            __import__(modname)
        <frozen importlib._bootstrap>:971: in _find_and_load
            ???
        <frozen importlib._bootstrap>:955: in _find_and_load_unlocked
            ???
        <frozen importlib._bootstrap>:656: in _load_unlocked
            ???
        <frozen importlib._bootstrap>:626: in _load_backward_compatible
            ???
        /usr/local/lib/python3.6/site-packages/_pytest/assertion/rewrite.py:216: in load_module
            py.builtin.exec_(co, mod.__dict__)
        test_hiker.py:1: in <module>
            import hiker
        E     File "/tmp/sandbox/hiker.py", line 5
        E       return 6 * 9synax-error
        E                       ^
        E   SyntaxError: invalid syntax
        !!!!!!!!!!!!!!!!!!! Interrupted: 1 errors during collection !!!!!!!!!!!!!!!!!!!!
        =========================== 1 error in 0.21 seconds ============================
        STDOUT_AMBER

      # - - - - - - - - - - - - - - - - - - - - - - - -

      STDOUT_GREEN =
        <<~STDOUT_GREEN
        ============================= test session starts ==============================
        platform linux -- Python 3.6.5, pytest-3.6.2, py-1.5.3, pluggy-0.6.0
        rootdir: /tmp/sandbox, inifile:
        collected 1 item

        test_hiker.py .                                                          [100%]

        =========================== 1 passed in 0.01 seconds ===========================
        STDOUT_GREEN

    end
  end
end
