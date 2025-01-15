#!/bin/bash
usage="$(basename "$0") [-h] [-d DISTRO] [-r RELEASE] [-p \"PACKAGE1 PACKAGE2 ..\"] [-k AABBCCDDEEFF0011] [-t \"ppa:user/ppa\"] [-s]
Download deb-package(s) for given distribution release,
where:
    -h  show this help text
    -d  distro name (debian, ubuntu, mint, astra, kali)
    -r  release name (buster, focal, 20.3, 2.12, rolling)
    -p  packages
    -k  key for apt-key command (optional)
    -t  extra PPA repository for Ubuntu or full deb-line (optional)
    -s  also download source-code for deb-package(s) (optional)
    -b  use deb-package(s) from backports pocket (optional)"

get_source=0
use_backports=0
while getopts ":hd:r:p:k:t:sb" opt; do
  case "$opt" in
    h) echo "$usage"; exit;;
    d) distro=$OPTARG;;
    r) release=$OPTARG;;
    p) packages=$OPTARG;;
    k) apt_key=$OPTARG;;
    t) third_party_repo=$OPTARG;;
    s) get_source=1;;
    b) use_backports=1;;
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
use_backports_command=""

# distros and their versions
supported_ubuntu_releases="trusty|xenial|bionic|focal|jammy|noble|oracular|devel";
eol_ubuntu_releases="precise|quantal|raring|saucy|utopic|vivid|wily|yakkety|zesty|artful|cosmic|disco|eoan|groovy|hirsute|impish|kinetic|lunar|mantic";
ubuntu_release_is_eol=0;

supported_debian_releases="oldoldstable|buster|oldstable|bullseye|stable|bookworm";
debian_releases_newsecurity="oldstable|bullseye|stable|bookworm";
testing_debian_releases="testing|trixie";
rolling_debian_releases="sid|unstable|experimental";
non_free_firmware_debian_releases="stable|bookworm|$testing_debian_releases|$rolling_debian_releases"
eol_debian_releases="squeeze|wheezy|jessie|stretch";
debian_release_is_eol=0;

supported_mint_releases="lmde5|lmde6|19$|19.1|19.2|19.3|20$|20.1|20.2|20.3|21$|21.1|21.2|21.3|22$|22.1";
eol_mint_releases="lmde4|17$|18$"; # lmde2 and lmde3 are broken because of archival

supported_astra_releases="2.12|1.7|1.8";
supported_kali_releases="rolling";

no_install_suggests="--no-install-suggests";
no_update="-n";
add_sources="";
gpg_pkg="gpg";
software_properties_pkg="software-properties-common"

# main code

if [ "$distro" != "debian" ] && [ "$distro" != "ubuntu" ] && [ "$distro" != "mint" ] && [ "$distro" != "astra" ] && [ "$distro" != "kali" ]; then
    echo "Error: only Debian, Ubuntu, Mint, Astra and Kali are supported!";
    exit 1;
else
    if [ "$distro" == "ubuntu" ]; then
       ubuntu_releases="$supported_ubuntu_releases|$eol_ubuntu_releases"
       if ! echo "$release" | grep -wEq "$ubuntu_releases"
       then
            echo "Error: Ubuntu $release is not supported!";
            echo "Supported Ubuntu releases are ${ubuntu_releases//|/, }.";
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
       debian_releases="$supported_debian_releases|$eol_debian_releases|$testing_debian_releases|$rolling_debian_releases"
       if ! echo "$release" | grep -wEq "$debian_releases"
       then
            echo "Error: Debian $release is not supported!";
            echo "Supported Debian releases are ${debian_releases//|/, }.";
            exit 1;
       else
           if echo "$release" | grep -wEq "$eol_debian_releases"
           then
                echo "Warning: Debian $release is EOL, but script will continue run.";
                debian_release_is_eol=1;

                # workaround for Debain Squeeze - it does not have `--no-install-suggests` 
                # and has problem with GPG signature
                if [[ "$release" == "squeeze" || "$release" == "jessie" ]]; then
                    no_install_suggests="--force-yes";
                fi
           fi
       fi
    fi

    if [ "$distro" == "mint" ]; then
       mint_releases="$supported_mint_releases|$eol_mint_releases"
       if ! echo "$release" | grep -wEq "$mint_releases"
       then
            echo "Error: Mint $release is not supported!";
            mint_temp="${mint_releases//|/, }"
            echo "Supported Mint releases are ${mint_temp//$/}".;
            exit 1;
       else
           if echo "$release" | grep -wEq "$eol_mint_releases"
           then
                echo "Warning: Mint $release is EOL, but script will continue run.";
           fi
       fi
    fi

    if [ "$distro" == "astra" ]; then
       if ! echo "$release" | grep -wEq "$supported_astra_releases"
       then
            echo "Error: Astra $release is not supported!";
            echo "Supported Astra releases are ${supported_astra_releases//|/, }".;
            exit 1;
       fi
    fi

    if [ "$distro" == "kali" ]; then
       if ! echo "$release" | grep -wEq "$supported_kali_releases"
       then
            echo "Error: Kali $release is not supported!";
            echo "Supported Kali releases are ${supported_kali_releases//|/, }".;
            exit 1;
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
elif [ "$distro" == "astra" ]; then
    if [ "$release" == "2.12" ]; then
      echo "FROM registry.astralinux.ru/library/orel:latest" > Dockerfile
    elif [ "$release" == "1.7" ]; then
      echo "FROM registry.astralinux.ru/library/astra/ubi17:latest" > Dockerfile
    elif [ "$release" == "1.8" ]; then
      echo "FROM registry.astralinux.ru/library/astra/ubi18:1.8" > Dockerfile
    fi
elif [ "$distro" == "mint" ]; then
    if ! echo "$release" | grep -q "^lmde"
    then
      echo "FROM linuxmintd/mint$release-amd64" > Dockerfile
    else
      echo "FROM linuxmintd/$release-amd64" > Dockerfile
    fi
    no_update=""

    if [ $get_source == 1 ] && [ -n "$third_party_repo" ]; then
        echo "Warning: add-apt-repository on Mint does not support '-s' option, so getting sources is not possible, ignoring this option for third-party repositories."
    fi
else
    echo "FROM kalilinux/kali-$release" > Dockerfile
fi

if [ $use_backports == 1 ]; then
    if [[ "$distro" == "astra" || "$distro" == "mint" || "$distro" == "kali" ]]; then
        echo "Warning: backports are not yet supported for Astra, Kali and Mint."
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

        if [ $use_backports == 1 ]; then
          if [ "$release" != "precise" ]; then
            echo "RUN echo 'deb http://old-releases.ubuntu.com/ubuntu $release-backports main universe multiverse restricted' >> /etc/apt/sources.list" >> Dockerfile
            use_backports_command="-t $release-backports"
          fi
        fi

        if [ $get_source == 1 ]; then
            echo "RUN echo 'deb-src http://old-releases.ubuntu.com/ubuntu $release main universe multiverse restricted' >> /etc/apt/sources.list
RUN echo 'deb-src http://old-releases.ubuntu.com/ubuntu $release-updates main universe multiverse restricted' >> /etc/apt/sources.list
RUN echo 'deb-src http://old-releases.ubuntu.com/ubuntu $release-security main universe multiverse restricted' >> /etc/apt/sources.list" >> Dockerfile
            if [ $use_backports == 1 ]; then
              if [ "$release" != "precise" ]; then
                echo "RUN echo 'deb-src http://old-releases.ubuntu.com/ubuntu $release-backports main universe multiverse restricted' >> /etc/apt/sources.list" >> Dockerfile
              fi
            fi
        fi
    else # fixes missed *multiverse* for at least *precise*
        echo "RUN echo 'deb http://archive.ubuntu.com/ubuntu $release main universe multiverse restricted' > /etc/apt/sources.list
RUN echo 'deb http://archive.ubuntu.com/ubuntu $release-updates main universe multiverse restricted' >> /etc/apt/sources.list
RUN echo 'deb http://archive.ubuntu.com/ubuntu $release-security main universe multiverse restricted' >> /etc/apt/sources.list" >> Dockerfile

        if [ $use_backports == 1 ]; then
            echo "RUN echo 'deb http://archive.ubuntu.com/ubuntu $release-backports main universe multiverse restricted' >> /etc/apt/sources.list" >> Dockerfile
            use_backports_command="-t $release-backports"
        fi

        if [ $get_source == 1 ]; then
            echo "RUN echo 'deb-src http://archive.ubuntu.com/ubuntu $release main universe multiverse restricted' >> /etc/apt/sources.list
RUN echo 'deb-src http://archive.ubuntu.com/ubuntu $release-updates main universe multiverse restricted' >> /etc/apt/sources.list
RUN echo 'deb-src http://archive.ubuntu.com/ubuntu $release-security main universe multiverse restricted' >> /etc/apt/sources.list" >> Dockerfile

            if [ $use_backports == 1 ]; then
                echo "RUN echo 'deb-src http://archive.ubuntu.com/ubuntu $release-backports main universe multiverse restricted' >> /etc/apt/sources.list" >> Dockerfile
            fi
        fi
    fi
fi

if [ "$distro" == "debian" ]; then
    if [ $debian_release_is_eol == 1 ]; then
        echo "RUN echo 'deb http://archive.debian.org/debian $release main contrib non-free' > /etc/apt/sources.list" >> Dockerfile
        echo "RUN echo 'deb http://archive.debian.org/debian-security $release/updates main contrib non-free' >> /etc/apt/sources.list" >> Dockerfile

        if [ $get_source == 1 ]; then
            echo "RUN echo 'deb-src http://archive.debian.org/debian $release main contrib non-free' >> /etc/apt/sources.list" >> Dockerfile
            echo "RUN echo 'deb-src http://archive.debian.org/debian-security $release/updates main contrib non-free' >> /etc/apt/sources.list" >> Dockerfile
        fi
        
        if [ "$release" != "wheezy" ]; then
          if [ $use_backports == 1 ]; then
            echo "RUN echo 'deb http://archive.debian.org/debian/ $release-backports main contrib non-free' >> /etc/apt/sources.list" >> Dockerfile
            if [ $get_source == 1 ]; then
              echo "RUN echo 'deb-src http://archive.debian.org/debian/ $release-backports main contrib non-free' >> /etc/apt/sources.list" >> Dockerfile
            fi

            use_backports_command="--force-yes --allow-unauthenticated -t $release-backports"
          fi
        fi
    else # adding *contrib* and *non-free*
        echo "RUN echo 'deb http://deb.debian.org/debian/ $release main contrib non-free' > /etc/apt/sources.list" >> Dockerfile

        # adding *non-free-firmware* for *bookworm* and newer
        if echo "$release" | grep -wEq "$non_free_firmware_debian_releases"
        then
            echo "RUN echo 'deb http://deb.debian.org/debian/ $release non-free-firmware' >> /etc/apt/sources.list" >> Dockerfile
        fi

        if [ $use_backports == 1 ]; then
          if [ "$release" == "buster" ]; then
            echo "RUN echo 'deb http://archive.debian.org/debian buster-backports main contrib non-free' >> /etc/apt/sources.list" >> Dockerfile
          else
            echo "RUN echo 'deb http://deb.debian.org/debian/ $release-backports main contrib non-free' >> /etc/apt/sources.list" >> Dockerfile
          fi

            # adding *non-free-firmware* for *bookworm* and newer
            if echo "$release" | grep -wEq "$non_free_firmware_debian_releases"
            then
                echo "RUN echo 'deb http://deb.debian.org/debian/ $release-backports non-free-firmware' >> /etc/apt/sources.list" >> Dockerfile
            fi
            use_backports_command="-t $release-backports"
        fi

        if [ $get_source == 1 ]; then
            echo "RUN echo 'deb-src http://deb.debian.org/debian/ $release main contrib non-free' >> /etc/apt/sources.list" >> Dockerfile

            # adding *non-free-firmware* for *bookworm* and newer
            if echo "$release" | grep -wEq "$non_free_firmware_debian_releases"
            then
                echo "RUN echo 'deb-src http://deb.debian.org/debian/ $release non-free-firmware' >> /etc/apt/sources.list" >> Dockerfile
            fi
            
            if [ $use_backports == 1 ]; then
              if [ "$release" == "buster" ]; then
                echo "RUN echo 'deb-src http://archive.debian.org/debian buster-backports main contrib non-free' >> /etc/apt/sources.list" >> Dockerfile
              else
                echo "RUN echo 'deb-src http://deb.debian.org/debian/ $release-backports main contrib non-free' >> /etc/apt/sources.list" >> Dockerfile
              fi

                # adding *non-free-firmware* for *bookworm* and newer
                if echo "$release" | grep -wEq "$non_free_firmware_debian_releases"
                then
                    echo "RUN echo 'deb-src http://deb.debian.org/debian/ $release-backports non-free-firmware' >> /etc/apt/sources.list" >> Dockerfile
                fi
            fi
        fi

        # not adding updates
        if ! echo "$release" | grep -wEq "$rolling_debian_releases"
        then
            echo "RUN echo 'deb http://deb.debian.org/debian/ $release-updates main contrib non-free' >> /etc/apt/sources.list" >> Dockerfile

            # adding *non-free-firmware* for *bookworm* and newer
            if echo "$release" | grep -wEq "$non_free_firmware_debian_releases"
            then
                echo "RUN echo 'deb http://deb.debian.org/debian/ $release-updates non-free-firmware' >> /etc/apt/sources.list" >> Dockerfile
                echo "RUN echo 'deb http://security.debian.org/debian-security/ $release-security non-free-firmware' >> /etc/apt/sources.list" >> Dockerfile
            fi

            if [ $get_source == 1 ]; then
                echo "RUN echo 'deb-src http://deb.debian.org/debian/ $release-updates main contrib non-free' >> /etc/apt/sources.list" >> Dockerfile

                # adding *non-free-firmware* for *bookworm* and newer
                if echo "$release" | grep -wEq "$non_free_firmware_debian_releases"
                then
                    echo "RUN echo 'deb-src http://deb.debian.org/debian/ $release-updates non-free-firmware' >> /etc/apt/sources.list" >> Dockerfile
                    echo "RUN echo 'deb-src http://security.debian.org/debian-security/ $release-security non-free-firmware' >> /etc/apt/sources.list" >> Dockerfile
                fi
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

if [ "$distro" == "astra" ]; then
    if [ "$release" == "1.7" ]; then
        echo "RUN echo 'deb http://dl.astralinux.ru/astra/stable/1.7_x86-64/repository-main/     1.7_x86-64 main contrib non-free' > /etc/apt/sources.list
RUN echo 'deb http://dl.astralinux.ru/astra/stable/1.7_x86-64/repository-update/   1.7_x86-64 main contrib non-free' >> /etc/apt/sources.list
RUN echo 'deb http://dl.astralinux.ru/astra/stable/1.7_x86-64/repository-base/     1.7_x86-64 main contrib non-free' >> /etc/apt/sources.list
RUN echo 'deb http://dl.astralinux.ru/astra/stable/1.7_x86-64/repository-extended/ 1.7_x86-64 main contrib non-free' >> /etc/apt/sources.list
RUN echo '# deb http://dl.astralinux.ru/astra/stable/1.7_x86-64/repository-extended/ 1.7_x86-64 astra-ce' >> /etc/apt/sources.list" >> Dockerfile
    elif [ "$release" == "1.8" ]; then
        echo "RUN echo 'deb http://dl.astralinux.ru/astra/stable/1.8_x86-64/repository-main/     1.8_x86-64 main contrib non-free non-free-firmware' > /etc/apt/sources.list
RUN echo 'deb http://dl.astralinux.ru/astra/stable/1.8_x86-64/repository-extended/ 1.8_x86-64 main contrib non-free non-free-firmware' >> /etc/apt/sources.list" >> Dockerfile
    elif [ "$release" == "2.12" ]; then
        echo "RUN echo 'deb http://dl.astralinux.ru/astra/stable/2.12_x86-64/repository orel main contrib non-free' > /etc/apt/sources.list" >> Dockerfile
        no_update=""
    fi

    if [ $get_source == 1 ]; then
        echo "Warning: sources for Astra Linux are not available, but script will try to run further."
    fi
fi

if [ "$distro" == "kali" ]; then
    if [ $get_source == 1 ]; then
        echo "RUN echo 'deb-src http://http.kali.org/kali kali-$release main contrib non-free' >> /etc/apt/sources.list" >> Dockerfile
    fi
fi

# 32-bit packages
if [[ "$distro" == "debian" || "$distro" == "ubuntu" || "$distro" == "mint" || "$distro" == "astra" ]]; then
    # add 32-bit
    if [ "$(arch)" == "x86_64" ]; then
      if [[ "$release" != "squeeze" && "$release" != "precise" ]]; then
        echo "RUN dpkg --add-architecture i386" >> Dockerfile
      fi
    fi
fi

# source code
if [ $get_source == 1 ]; then
    if [ "$distro" != "mint" ] && [ -n "$third_party_repo" ]; then
        add_sources="-s";
    fi
    get_source_command="apt-get install dpkg-dev --no-install-recommends -y $use_backports_command && apt-get source ${packages[*]} $use_backports_command --print-uris | grep ^\'http:// | awk '{print \$1}' | sed \"s|'||g\" >> /var/cache/apt/archives/urls.txt && apt-get source ${packages[*]} $use_backports_command"
fi

# third-party repository key and PPA/deb-line
if [ -n "$apt_key" ]; then
    apt_key_command="apt-get install -y gnupg && apt-key adv --recv-keys --keyserver keyserver.ubuntu.com $apt_key"
fi
if [ -n "$third_party_repo" ]; then
    if [ "$distro" == "astra" ]; then
        echo "Warning: add-apt-repository command is not yet supported on AstraLinux, but script will try to run further."
    else
        if [ "$release" == "precise" ]; then
            software_properties_pkg="python-software-properties"
            gpg_pkg=""
            no_update=""
            if [ $get_source == 1 ]; then
                add_sources="" # not needed on precise, deb-src is already enabled automatically
            fi
        elif [[ "$release" == "trusty" || "$release" == "xenial" ]]; then
            gpg_pkg=""
            no_update=""
        fi

        third_party_repo_command="apt-get install -y python3-launchpadlib || apt-get install -y python-launchpadlib || true; apt-get install $software_properties_pkg gnupg $gpg_pkg dirmngr --no-install-recommends -y && add-apt-repository -y $add_sources $no_update \"$third_party_repo\" && apt-get update";
    fi
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
apt-get install -y --no-install-recommends $no_install_suggests --reinstall --download-only ${packages[*]} $use_backports_command --print-uris | grep ^\'http:// | awk '{print \$1}' | sed "s|'||g" >> /var/cache/apt/archives/urls.txt &&
apt-get install -y --no-install-recommends $no_install_suggests --reinstall --download-only ${packages[*]} $use_backports_command
chown -R "$(id --user):$(id --group)" /var/cache/apt/archives
EOF

# build container
docker build . -t "dd-$distro-$release"

# run script inside container
docker run --rm -v "${PWD}":/var/cache/apt/archives -it "dd-$distro-$release" sh /var/cache/apt/archives/script.sh
