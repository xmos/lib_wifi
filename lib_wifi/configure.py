#!/usr/bin/env python
import sys
import os.path
import re
import subprocess
import shutil
import stat

def run():
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
        exit(1)

    wiced_clone_point = os.path.join(lib_wifi_lib_dir, "src", "broadcom_wiced")
    wiced_repo = os.path.join(wiced_clone_point, "sdk")

    # Run as "python configure.py clean"
    if (len(sys.argv) > 1) and (sys.argv[1] == 'clean'):

        # If rmtree errors on a read only file, this function is called on it
        def del_rw(action, name, exc):
            os.chmod(name, stat.S_IWRITE)
            os.remove(name)

        # Delete local copy of the SDK if it already exists in lib_wifi
        if os.path.exists(wiced_repo):
            print "Removing Broadcom SDK..."
            shutil.rmtree(wiced_repo, onerror=del_rw)
        else:
            print "No Broadcom SDK to clean"
        exit(0)

    # Run as "python configure.py"
    if not os.path.exists(wiced_repo):
        print "Broadcom SDK not yet present"
        wiced_src_repo = "git://git/broadcom_wiced_sdk"
        subprocess.call(["git", "clone", wiced_src_repo, "sdk"],
                        cwd=wiced_clone_point)
    else:
        print "Broadcom SDK already exists"
        subprocess.call(["git", "pull"], cwd=wiced_clone_point)

    print "Creating/updating patch"
    with open(os.path.join(wiced_clone_point, "xcore_compat.patch"), "w") as f:
        subprocess.call(["git", "diff", "-p", "v" + wiced_version, "HEAD"],
                        stdout=f, cwd=wiced_repo)

if __name__ == "__main__":
    run()
