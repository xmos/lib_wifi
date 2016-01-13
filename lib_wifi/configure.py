#!/usr/bin/env python
import os.path
import re
import subprocess
import shutil

if __name__ == "__main__":
  # Extract WICED_SDK_VERSION value from module_build_info
  wiced_version = None
  lib_wifi_lib_dir = os.path.dirname(os.path.realpath(__file__))
  module_build_info_file = os.path.abspath(os.path.join(lib_wifi_lib_dir,
                                            "module_build_info"))
  with open(module_build_info_file, 'r') as module_build_info:
    for line in module_build_info.readlines():
      version_match = re.match(r'WICED_SDK_VERSION \?\= (\d+\.\d+\.\d+)', line)
      if version_match:
        wiced_version = version_match.group(1)
        break

  if not wiced_version:
    print "Unable to find WICED SDK version in module_build_info"
    exit(30)

  wiced_dir_name = "WICED-SDK-"+wiced_version
  wiced_src_repo = os.path.join(lib_wifi_lib_dir, "..", "..",
                                "lib_broadcom_wiced_sdk")
  wiced_src_dir = os.path.join(wiced_src_repo, wiced_dir_name)
  lib_wifi_sdk_dir = os.path.join(lib_wifi_lib_dir,  "src",
                                  "broadcom_wiced", "sdk")
  wiced_dst_dir = os.path.join(lib_wifi_sdk_dir, wiced_dir_name)

  # Check that the sandbox contains the correct SDK version
  git_proc = subprocess.Popen(["git name-rev --tags --name-only "
                             "$(git rev-parse HEAD)"],
                             cwd=wiced_src_repo,
                             stdout=subprocess.PIPE,
                             shell=True)
  git_return = git_proc.wait()
  if git_return != 0:
    print "Unexpected git error while checking tag in WICED SDK source repo"
    exit(32)
  git_tag = git_proc.stdout.readlines()
  expected_tag = "v"+wiced_version
  if git_tag[0].strip() != expected_tag:
    print("%s is not checked out at the expected tag %s!" % (wiced_src_repo,
                                                             expected_tag))
    exit(33)

  # Delete local copy of the SDK if it already exists in lib_wifi
  if os.path.exists(wiced_dst_dir):
    print "Removing existing copy of WICED SDK..."
    shutil.rmtree(wiced_dst_dir)

  # Copy SDK dir from lib_broadcom_wiced_sdk to patch location
  print "Copying WICED SDK to required location..."
  shutil.copytree(wiced_src_dir, wiced_dst_dir)

  # Apply the patch to the WICED SDK files
  result = subprocess.check_call(["patch", "-p1", "-i", "xcore_compat.patch"],
                                 cwd=lib_wifi_sdk_dir)

  exit(result) # Patch will exit with 1 or 2 on error
