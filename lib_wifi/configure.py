#!/usr/bin/env python
import sys
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
            version_match = re.match(r'WICED_SDK_VERSION \?\= (\d+\.\d+\.\d+)',
                                     line)
            if version_match:
                wiced_version = version_match.group(1)
                break

    if not wiced_version:
        print "Unable to find WICED SDK version in module_build_info"
        exit(30)

    print "Getting broadcom SDK - ",
    wiced_clone_point = os.path.join(lib_wifi_lib_dir, "src", "broadcom_wiced")
    wiced_repo = os.path.join(wiced_clone_point, "sdk")
    if not os.path.exists(wiced_repo):
        print "Cloning Repo"
        wiced_src_repo = "git://git/broadcom_wiced_sdk"
        subprocess.call(["git", "clone", wiced_src_repo, "sdk"],
                        cwd=wiced_clone_point)
    else:
        print "Already exists"

    print "Creating patch"
    with open(os.path.join(wiced_clone_point, "xcore_compat.patch"), "w") as f:
        subprocess.call(["git", "diff", "-p", "v" + wiced_version, "HEAD"],
                        stdout=f, cwd=wiced_repo)
