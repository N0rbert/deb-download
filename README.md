# deb-download

Shell script for downloading deb-package(s) from modern Debian or Ubuntu repositories

Under the hood this script uses Docker to obtain minimal file-system of needed system release. And then it download package(s) to the `storage` sub-directory and saves the list of download URL(s) in `storage/urls.txt` file. The created Docker images will be named with `dd-` prefix, you can remove them manually later.

The main motivation to write this script was partial removal of Python 2 stuff from Ubuntu 20.04 LTS official repositories. For regular users this means that applications like ZeNMap, FSLint are no longer available from `apt`/`apt-get`. So users need to download them manually from <https://packages.ubuntu.com>. This script automates this process.

The `deb-download.sh` takes at least three arguments, as shown in example below:

```
./deb-download.sh ubuntu bionic zenmap
```

* 1st is distribution - `debian` for Debian or `ubuntu` for Ubuntu;
* 2nd is version - all versions starting from Debian 6 (`squeeze`) and Ubuntu 12.04 LTS (`precise`) are supported;
* 3rd and greater - represent package(s) name(s) - in the above example it is single `zenmap` package.

Note: if you have configured proxy in your network, then you can supply its address as the argument to the application - `http_proxy=http://192.168.12.34:8000 ./deb-download.sh ubuntu bionic zenmap` .

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

       cd ~/deb-download
       chmod +x deb-download.sh
       ./deb-download.sh ubuntu bionic fslint

1. Carefully inspect the contents of `./storage` folder, then try to install main deb-package to the target system, then fix its dependencies one-by-one. For better understanding consult with <https://packages.ubuntu.com>.

   Please also note that this `./storage` folder will be cleared on next run of the script!

**Warning:** author of this script can't provide any warranty about successful installation of downloaded deb-packages on the target system. Be careful!

