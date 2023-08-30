import os
import sys
import argparse
import pytest


def run_all_tests(test_path: str = None):
    if not test_path:
        test_path = os.path.dirname(os.path.abspath(__file__))
    return pytest.main(["-x", test_path])


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Parameters')
    parser.add_argument('--testPath', required=False, default=None, help="Base path of all tests")
    args = parser.parse_args()

    exitcode = run_all_tests(args.testPath)
    if exitcode != 0:
        raise Exception(f"pytest exitcode is non zero: {exitcode}")
