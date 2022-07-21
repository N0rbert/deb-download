# deb-download

Shell script for downloading deb-package(s) from modern Debian or Ubuntu repositories

Under the hood this script uses Docker to obtain minimal file-system of needed system release. And then it download package(s) to the `storage` sub-directory and saves the list of download URL(s) in `storage/urls.txt` file. The created Docker images will be named with `dd-` prefix, you can remove them manually later.

The main motivation to write this script was partial removal of Python 2 stuff from Ubuntu 20.04 LTS official repositories. For regular users this means that applications like ZeNMap, FSLint are no longer available from `apt`/`apt-get`. So users need to download them manually from <https://packages.ubuntu.com>. This script automates this process.

The `deb-download.sh` takes at least three pairs of arguments, as shown in example below:

```
./deb-download.sh -d ubuntu -r bionic -p zenmap
```

* `-d` (distribution, mandatory) - `debian` for Debian, `ubuntu` for Ubuntu or `mint` for LinuxMint;
* `-r` (release, mandatory) - all versions starting from Debian 6 (`squeeze`), Ubuntu 12.04 LTS (`precise`) and LinuxMint (`17`) are supported by script;
* `-p` (with quotes for multiple packages, mandatory) - represent package(s) name(s) - in the above example it is single `zenmap` package. For two packages use `"mc htop"` (for example);
* `-t` (third-party PPA or full deb-line for `add-apt-repository`, optional) - for example `ppa:user/repo` or `deb http://ppa.launchpad.net/user/repo/ubuntu bionic main` with the corresponding key for `apt-key` (`-k AABBCCDDEEFF0011` for this example).

Note: if you have configured proxy in your network, then you can supply its address as the argument to the application - `http_proxy=http://192.168.12.34:8000 ./deb-download.sh -d ubuntu -r bionic -p zenmap` .

How to start using this script:

1. Install Docker and dependencies to the host system
   
       sudo apt-get update
       sudo apt-get install docker.io git

1. Add current user to the `docker` group
   
       sudo usermod -a -G docker $USER
   
   then reboot machine.

1. Clone this repository

       cd ~/Downloads
       git clone https://github.com/N0rbert/deb-download.git

1. Fetch some random deb-package

       cd deb-download
       chmod +x deb-download.sh
       ./deb-download.sh -d ubuntu -r bionic -p fslint

1. Carefully inspect the contents of `storage` folder, then try to install main deb-package to the target system, then fix its dependencies one-by-one. For better understanding consult with <https://packages.ubuntu.com>.

   Please also note that this `storage` folder will be cleared on next run of the script!

**Warning:** author of this script can't provide any warranty about successful installation of downloaded deb-packages on the target system. Be careful!
