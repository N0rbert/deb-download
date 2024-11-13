# deb-download

Shell script for downloading deb-package(s) from modern Debian or Ubuntu repositories

Under the hood this script uses Docker to obtain minimal file-system of needed system release. And then it download package(s) to the `storage` sub-directory and saves the list of download URL(s) in `storage/urls.txt` file. The created Docker images will be named with `dd-` prefix, you can remove them manually later.

The main motivation to write this script was partial removal of Python 2 stuff from Ubuntu 20.04 LTS official repositories. For regular users this means that applications like ZeNMap, FSLint are no longer available from `apt`/`apt-get`. So users need to download them manually from <https://packages.ubuntu.com>. This script automates this process.

The `deb-download.sh` takes at least three pairs of arguments, as shown in example below:

```
./deb-download.sh -d ubuntu -r bionic -p zenmap
```

* `-d` (distribution, mandatory) - `debian` for Debian, `ubuntu` for Ubuntu, `mint` for LinuxMint, `astra` for AstraLinux or `kali` for Kali Linux;
* `-r` (release, mandatory) - all versions starting from Debian 6 (`squeeze`), Ubuntu 12.04 LTS (`precise`), LinuxMint (`17`), AstraLinux (`2.12`, `1.7` and `1.8`) and Kali Linux (`rolling`) are supported by script;
* `-p` (with quotes for multiple packages, mandatory) - represent package(s) name(s) - in the above example it is single `zenmap` package. For two packages use `"mc htop"` (for example);
* `-t` (third-party PPA or full deb-line for `add-apt-repository`, optional) - for example `ppa:user/repo` or `deb http://ppa.launchpad.net/user/repo/ubuntu bionic main` with the corresponding key for `apt-key` (`-k AABBCCDDEEFF0011` for this example);
* `-s` (get source code of Debian or Ubuntu package(s), optional);
* `-b` (use deb-package(s) from backports pocket, optional).

Note: if you have configured proxy in your network, then you can supply its address as the argument to the application - `http_proxy=http://192.168.12.34:8000 ./deb-download.sh -d ubuntu -r bionic -p zenmap` .

## How to start using this script:

1. Dependencies:
   - [Docker](https://docs.docker.com/engine/install/)
   - [Curl](https://curl.se/download.html)

2. Use it:


       curl -sL https://raw.githubusercontent.com/N0rbert/deb-download/refs/heads/master/deb-download.sh \
       | bash -s -- *args 
    e.g.

       curl -sL https://raw.githubusercontent.com/N0rbert/deb-download/refs/heads/master/deb-download.sh \
       | bash -s --  -d ubuntu -r bionic -p fslint


3. Carefully inspect the contents of `storage` folder, then try to install main deb-package to the target system, then fix its dependencies one-by-one. For better understanding consult with <https://packages.ubuntu.com>.

   Please also note that this `storage` folder will be cleared on next run of the script!

**Warning:** author of this script can't provide any warranty about successful installation of downloaded deb-packages on the target system. Be careful!
