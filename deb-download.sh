#!/bin/bash
USAGE="Usage: $0 distro release package-name-1 ... package-name-N"

if [ $# -lt 3 ]; then
	echo "$USAGE";
	exit 1;
fi

distro="$1";
release="$2";
packages=${@:3};

supported_ubuntu_releases="precise|trusty|bionic|focal|groovy|hirsute|devel";
eol_ubuntu_releases="quantal|raring|saucy|utopic|vivid|wily|yakkety|zesty|artful|cosmic|disco|eoan";
ubuntu_release_is_eol=0;

supported_debian_releases="jessie|oldoldstable|stretch|oldstable|buster|stable";
testing_debian_releases="bullseye|testing";
rolling_debian_releases="sid|unstable|experimental";
eol_debian_releases="squeeze|wheezy";
debian_release_is_eol=0;

no_install_suggests="--no-install-suggests";

if [ "$distro" != "debian" -a "$distro" != "ubuntu" ]; then
    echo "Error: only Debian and Ubuntu are supported!";
    exit 1;
else
    if [ "$distro" == "ubuntu" ]; then
       if ! echo $release | grep -wEq "$supported_ubuntu_releases|$eol_ubuntu_releases"
       then
            echo "Error: Ubuntu $release is not supported!";
            exit 1;
       else
           if echo $release | grep -wEq "$eol_ubuntu_releases"
           then
                echo "Warning: Ubuntu $release is EOL, but script will continue run.";
                ubuntu_release_is_eol=1;
           fi
       fi
    fi

    if [ "$distro" == "debian" ]; then
       if ! echo $release | grep -wEq "$supported_debian_releases|$eol_debian_releases|$testing_debian_releases|$rolling_debian_releases"
       then
            echo "Error: Debian $release is not supported!";
            exit 1;
       else
           if echo $release | grep -wEq "$eol_debian_releases"
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
fi

# prepare storage folder
rm -rf storage
mkdir storage
cd storage

# prepare Dockerfile
cat << EOF > Dockerfile
FROM $distro:$release
RUN [ -z "$http_proxy" ] && echo "Using direct network connection" || echo 'Acquire::http::Proxy "$http_proxy";' > /etc/apt/apt.conf.d/99proxy
EOF

if [ "$distro" == "ubuntu" ]; then
    if [ $ubuntu_release_is_eol == 1 ]; then
        echo "RUN echo 'deb http://old-releases.ubuntu.com/ubuntu $release main universe multiverse restricted' > /etc/apt/sources.list" >> Dockerfile
        echo "RUN echo 'deb http://old-releases.ubuntu.com/ubuntu $release-updates main universe multiverse restricted' >> /etc/apt/sources.list" >> Dockerfile
        echo "RUN echo 'deb http://old-releases.ubuntu.com/ubuntu $release-security main universe multiverse restricted' >> /etc/apt/sources.list" >> Dockerfile
    else # fixes missed *multiverse* for at least *precise*
        echo "RUN echo 'deb http://archive.ubuntu.com/ubuntu $release main universe multiverse restricted' > /etc/apt/sources.list" >> Dockerfile
        echo "RUN echo 'deb http://archive.ubuntu.com/ubuntu $release-updates main universe multiverse restricted' >> /etc/apt/sources.list" >> Dockerfile
        echo "RUN echo 'deb http://archive.ubuntu.com/ubuntu $release-security main universe multiverse restricted' >> /etc/apt/sources.list" >> Dockerfile
    fi
else
    if [ $debian_release_is_eol == 1 ]; then
        echo "RUN echo 'deb http://archive.debian.org/debian $release main contrib non-free' > /etc/apt/sources.list" >> Dockerfile
    else # adding *contrib* and *non-free*
        echo "RUN echo 'deb http://deb.debian.org/debian/ $release main contrib non-free' > /etc/apt/sources.list" >> Dockerfile

        # not adding updates
        if ! echo $release | grep -wEq "$rolling_debian_releases"
        then
            echo "RUN echo 'deb http://deb.debian.org/debian/ $release-updates main contrib non-free' >> /etc/apt/sources.list" >> Dockerfile
        fi

        # not adding debian-security
        if ! echo $release | grep -wEq "$testing_debian_releases|$rolling_debian_releases"
        then
            echo "RUN echo 'deb http://security.debian.org/debian-security/ $release/updates main contrib non-free' >> /etc/apt/sources.list" >> Dockerfile
        fi
    fi
fi

# prepare download script
cat << EOF > script.sh
set -x

apt-get update && \
apt-get install -y --no-install-recommends $no_install_suggests --reinstall --download-only $packages --print-uris | grep ^\'http:// | awk '{print \$1}' | sed "s|'||g" > /var/cache/apt/archives/urls.txt &&
apt-get install -y --no-install-recommends $no_install_suggests --reinstall --download-only $packages
EOF

# build container
docker build . -t "dd-$release"

# run script inside container
docker run -v ${PWD}:/var/cache/apt/archives -it "dd-$release" sh /var/cache/apt/archives/script.sh
