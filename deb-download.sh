#!/bin/bash
usage="$(basename "$0") [-h] [-d DISTRO] [-r RELEASE] [-p \"PACKAGE1 PACKAGE2 ..\"] [-k AABBCCDDEEFF0011] [-t \"ppa:user/ppa\"] [-s]
Download deb-package(s) for given distribution release,
where:
    -h  show this help text
    -d  distro name (debian, ubuntu, mint)
    -r  release name (buster, focal, 20.3)
    -p  packages
    -k  key for apt-key command (optional)
    -t  extra PPA repository for Ubuntu (optional)
    -s  also download source-code for Debian or Ubuntu package(s) (optional)"

get_source=0
while getopts ":hd:r:p:k:t:s" opt; do
  case "$opt" in
    h) echo "$usage"; exit;;
    d) distro=$OPTARG;;
    r) release=$OPTARG;;
    p) packages=$OPTARG;;
    k) apt_key=$OPTARG;;
    t) third_party_repo=$OPTARG;;
    s) get_source=1;;
    \?) echo "Error: Unimplemented option chosen!"; echo "$usage" >&2; exit 1;;
  esac
done

# mandatory arguments
if [ ! "$distro" ] || [ ! "$release" ] || [ ! "$packages" ]; then
  echo "Error: arguments -d, -r and -p must be provided!"
  echo "$usage" >&2; exit 1
fi

# commands which are dynamically generated from optional arguments
apt_key_command="true"
third_party_repo_command="true"
get_source_command="true"

# distros and their versions
supported_ubuntu_releases="trusty|xenial|bionic|focal|hirsute|impish|jammy|devel";
eol_ubuntu_releases="precise|quantal|raring|saucy|utopic|vivid|wily|yakkety|zesty|artful|cosmic|disco|eoan|groovy";
ubuntu_release_is_eol=0;

supported_debian_releases="jessie|oldoldstable|stretch|oldstable|buster|stable|bullseye";
debian_releases_newsecurity="stable|bullseye";
testing_debian_releases="bookworm|testing";
rolling_debian_releases="sid|unstable|experimental";
eol_debian_releases="squeeze|wheezy";
debian_release_is_eol=0;

supported_mint_releases="19$|19.1|19.2|19.3|20$|20.1|20.2|20.3";
eol_mint_releases="17$|18$";

no_install_suggests="--no-install-suggests";
no_update="-n";
add_sources="";

# main code

if [ "$distro" != "debian" ] && [ "$distro" != "ubuntu" ] && [ "$distro" != "mint" ]; then
    echo "Error: only Debian, Ubuntu and Mint are supported!";
    exit 1;
else
    if [ "$distro" == "ubuntu" ]; then
       if ! echo "$release" | grep -wEq "$supported_ubuntu_releases|$eol_ubuntu_releases"
       then
            echo "Error: Ubuntu $release is not supported!";
            exit 1;
       else
           if echo "$release" | grep -wEq "$eol_ubuntu_releases"
           then
                echo "Warning: Ubuntu $release is EOL, but script will continue to run.";
                ubuntu_release_is_eol=1;
           fi
       fi
    fi

    if [ "$distro" == "debian" ]; then
       if ! echo "$release" | grep -wEq "$supported_debian_releases|$eol_debian_releases|$testing_debian_releases|$rolling_debian_releases"
       then
            echo "Error: Debian $release is not supported!";
            exit 1;
       else
           if echo "$release" | grep -wEq "$eol_debian_releases"
           then
                echo "Warning: Debian $release is EOL, but script will continue run.";
                debian_release_is_eol=1;

                # workaround for Debain Squeeze - it does not have `--no-install-suggests` 
                # and has problem with GPG signature
                if [ "$release" == "squeeze" ]; then
                    no_install_suggests="--force-yes";
                fi
           fi
       fi
    fi

    if [ "$distro" == "mint" ]; then
       if ! echo "$release" | grep -wEq "$supported_mint_releases|$eol_mint_releases"
       then
            echo "Error: Mint $release is not supported!";
            exit 1;
       else
           if echo "$release" | grep -wEq "$eol_mint_releases"
           then
                echo "Warning: Mint $release is EOL, but script will continue run.";
           fi
       fi
    fi
fi

# prepare storage folder
rm -rf storage
mkdir -p storage
cd storage || { echo "Error: can't cd to storage directory!"; exit 3; }

# prepare Dockerfile
if [ "$distro" == "ubuntu" ] || [ "$distro" == "debian" ]; then
    echo "FROM $distro:$release" > Dockerfile
else
    echo "FROM linuxmintd/mint$release-amd64" > Dockerfile
    no_update=""

    if [ $get_source == 1 ] && [ -n "$third_party_repo" ]; then
        echo "Warning: add-apt-repository on Mint does not support '-s' option, so getting sources is not possible, ignoring this option for third-party repositories."
    fi
fi

cat << EOF >> Dockerfile
RUN [ -z "$http_proxy" ] && echo "Using direct network connection" || echo 'Acquire::http::Proxy "$http_proxy";' > /etc/apt/apt.conf.d/99proxy
EOF

if [ "$distro" == "ubuntu" ]; then
    if [ $ubuntu_release_is_eol == 1 ]; then
        echo "RUN echo 'deb http://old-releases.ubuntu.com/ubuntu $release main universe multiverse restricted' > /etc/apt/sources.list
RUN echo 'deb http://old-releases.ubuntu.com/ubuntu $release-updates main universe multiverse restricted' >> /etc/apt/sources.list
RUN echo 'deb http://old-releases.ubuntu.com/ubuntu $release-security main universe multiverse restricted' >> /etc/apt/sources.list" >> Dockerfile

        if [ $get_source == 1 ]; then
            echo "RUN echo 'deb-src http://old-releases.ubuntu.com/ubuntu $release main universe multiverse restricted' >> /etc/apt/sources.list
RUN echo 'deb-src http://old-releases.ubuntu.com/ubuntu $release-updates main universe multiverse restricted' >> /etc/apt/sources.list
RUN echo 'deb-src http://old-releases.ubuntu.com/ubuntu $release-security main universe multiverse restricted' >> /etc/apt/sources.list" >> Dockerfile
        fi
    else # fixes missed *multiverse* for at least *precise*
        echo "RUN echo 'deb http://archive.ubuntu.com/ubuntu $release main universe multiverse restricted' > /etc/apt/sources.list
RUN echo 'deb http://archive.ubuntu.com/ubuntu $release-updates main universe multiverse restricted' >> /etc/apt/sources.list
RUN echo 'deb http://archive.ubuntu.com/ubuntu $release-security main universe multiverse restricted' >> /etc/apt/sources.list" >> Dockerfile

        if [ $get_source == 1 ]; then
            echo "RUN echo 'deb-src http://archive.ubuntu.com/ubuntu $release main universe multiverse restricted' >> /etc/apt/sources.list
RUN echo 'deb-src http://archive.ubuntu.com/ubuntu $release-updates main universe multiverse restricted' >> /etc/apt/sources.list
RUN echo 'deb-src http://archive.ubuntu.com/ubuntu $release-security main universe multiverse restricted' >> /etc/apt/sources.list" >> Dockerfile
        fi
    fi
fi

if [ "$distro" == "debian" ]; then
    if [ $debian_release_is_eol == 1 ]; then
        echo "RUN echo 'deb http://archive.debian.org/debian $release main contrib non-free' > /etc/apt/sources.list" >> Dockerfile

        if [ $get_source == 1 ]; then
            echo "RUN echo 'deb-src http://archive.debian.org/debian $release main contrib non-free' >> /etc/apt/sources.list" >> Dockerfile
        fi
    else # adding *contrib* and *non-free*
        echo "RUN echo 'deb http://deb.debian.org/debian/ $release main contrib non-free' > /etc/apt/sources.list" >> Dockerfile

        if [ $get_source == 1 ]; then
            echo "RUN echo 'deb-src http://deb.debian.org/debian/ $release main contrib non-free' >> /etc/apt/sources.list" >> Dockerfile
        fi

        # not adding updates
        if ! echo "$release" | grep -wEq "$rolling_debian_releases"
        then
            echo "RUN echo 'deb http://deb.debian.org/debian/ $release-updates main contrib non-free' >> /etc/apt/sources.list" >> Dockerfile

            if [ $get_source == 1 ]; then
                echo "RUN echo 'deb-src http://deb.debian.org/debian/ $release-updates main contrib non-free' >> /etc/apt/sources.list" >> Dockerfile
            fi
        fi

        # not adding debian-security
        if ! echo "$release" | grep -wEq "$testing_debian_releases|$rolling_debian_releases|$debian_releases_newsecurity"
        then
            echo "RUN echo 'deb http://security.debian.org/debian-security/ $release/updates main contrib non-free' >> /etc/apt/sources.list" >> Dockerfile

            if [ $get_source == 1 ]; then
                echo "RUN echo 'deb-src http://security.debian.org/debian-security/ $release/updates main contrib non-free' >> /etc/apt/sources.list" >> Dockerfile
            fi
        fi
        
        # adding security in new fashion
        if echo "$release" | grep -wEq "$debian_releases_newsecurity"
        then
            echo "RUN echo 'deb http://security.debian.org/debian-security/ $release-security main contrib non-free' >> /etc/apt/sources.list" >> Dockerfile

            if [ $get_source == 1 ]; then
                echo "RUN echo 'deb-src http://security.debian.org/debian-security/ $release-security main contrib non-free' >> /etc/apt/sources.list" >> Dockerfile
            fi
        fi

        no_update=""
    fi
fi

# source code
if [ $get_source == 1 ]; then
    if [ "$distro" != "mint" ] && [ -n "$third_party_repo" ]; then
        add_sources="-s";
    fi
    get_source_command="apt-get install dpkg-dev --no-install-recommends -y && apt-get source ${packages[*]}"
fi

# third-party repository key and PPA/deb-line
if [ -n "$apt_key" ]; then
    apt_key_command="apt-get install -y gnupg && apt-key adv --recv-keys --keyserver keyserver.ubuntu.com $apt_key"
fi
if [ -n "$third_party_repo" ]; then
    third_party_repo_command="apt-get install software-properties-common gpg dirmngr --no-install-recommends -y && add-apt-repository -y $add_sources $no_update \"$third_party_repo\" && apt-get update";
fi

# prepare download script
cat << EOF > script.sh
set -x

export DEBIAN_FRONTEND=noninteractive
rm -rfv /var/cache/apt/archives/partial
cd /var/cache/apt/archives
apt-get update && \
$apt_key_command && \
$third_party_repo_command && \
$get_source_command || true && \
apt-get install -y --no-install-recommends $no_install_suggests --reinstall --download-only ${packages[*]} --print-uris | grep ^\'http:// | awk '{print \$1}' | sed "s|'||g" > /var/cache/apt/archives/urls.txt &&
apt-get install -y --no-install-recommends $no_install_suggests --reinstall --download-only ${packages[*]}
chown -R "$(id --user):$(id --group)" /var/cache/apt/archives
EOF

# build container
docker build . -t "dd-$distro-$release"

# run script inside container
docker run --rm -v "${PWD}":/var/cache/apt/archives -it "dd-$distro-$release" sh /var/cache/apt/archives/script.sh
