Debian Image Builder
====================

This repository provides a collection of scripts as proof of concept for scripted

- Generation of debian base images for docker and libvirt
- Generation/Cloning/Provisioning of VMs

They are meant to document the result of learning and experimenting with the
kvm/libvirt stack. In combination with the collection of recipes/links in the
appendix, they might provide a good introduction into the topics.

.. contents:: Table of Contents


Goals
-----

- Usage of commands/scripts instead of GUIs
- Usage of debuerreotype to gain the advantage of reproducibility
- Generation of as similiar base images for docker/VMs as possible
- Generation of as minimal VM templates as possible for later provisioning with ansible
- Easy creation of test environments for ansible role development
- Foundation for automated build/deploy infrastructure for docker images and VMs
- Minimization of dependencies and neccessary trust


Tools
-----

- `debian`_: The universal operating system

  - `debootstrap`_: Main bootstrap tool for debian rootfs builds
  - `debuerreotype`_: `Reproducible`_ debian rootfs builds

    - Wrapper for debootstrap
    - Installs packages from arbritary `snapshots`_ in time
    - Creates disc space optimized minbase images (with docker in mind)
      used in the official debian docker hub repository.
    - Docker specific adjustments can be reverted (with VMs in mind)

  - `apt-cacher-ng`_: Cache for ``apt`` / ``apt-get`` packages (saves time and energy)

- `docker`_ *(Docker, Inc.)*: Container backend
- `libvirt`_ *(RedHat)*: VM backend, integrates kvm and qemu

  - `virsh`_: Main console CLI for libvirt VMs

- `virt-manager`_ *(RedHat)*: Set of helper tools for managing VM lifecycles

  - `virt-viewer`_: Displays graphical interface of VM
  - `virt-install`_: Installs new VMs
  - `virt-clone`_: Clones VMs
  - `virt-bootstrap`_: Creates filesystems from tar / docker image

- `libguestfs-tools`_ *(RedHat)*: Set of helper tools for handling VM filesystems

  - `virt-builder`_: Installs/provisions new VMs
  - `virt-make-fs`_: Creates filesystems from tar
  - `virt-customize`_: Customizes existing VMs
  - `virt-sysprep`_: Provisions/prepares existing VMs

- `ansible`_ *(RedHat)*: Provisions any machine

.. _debian:           https://www.debian.org
.. _debootstrap:      https://wiki.debian.org/Debootstrap
.. _debuerreotype:    https://github.com/debuerreotype/debuerreotype
.. _Reproducible:     https://wiki.debian.org/ReproducibleInstalls
.. _snapshots:        https://snapshot.debian.org
.. _apt-cacher-ng:    https://wiki.debian.org/AptCacherNg

.. _docker:           https://www.docker.com

.. _libvirt:          https://libvirt.org
.. _virsh:            https://manpages.debian.org/testing/libvirt-clients/virsh.1.en.html

.. _virt-manager:     https://virt-manager.org
.. _virt-viewer:      https://manpages.debian.org/testing/virt-viewer/virt-viewer.1.en.html
.. _virt-install:     https://manpages.debian.org/testing/virtinst/virt-install.1.en.html
.. _virt-clone:       https://manpages.debian.org/testing/virtinst/virt-clone.1.en.html
.. _virt-bootstrap:   https://github.com/virt-manager/virt-bootstrap

.. _libguestfs-tools: https://libguestfs.org
.. _virt-builder:     https://manpages.debian.org/testing/guestfs-tools/virt-builder.1.en.html
.. _virt-make-fs:     https://manpages.debian.org/testing/guestfs-tools/virt-make-fs.1.en.html
.. _virt-customize:   https://manpages.debian.org/testing/guestfs-tools/virt-customize.1.en.html
.. _virt-sysprep:     https://manpages.debian.org/testing/guestfs-tools/virt-sysprep.1.en.html


Features
--------

- [x] Generate debian rootfs

  - [ ] `netinst iso`_ / debian-installer + preseed
  - [ ] `cloud image`_ (Plain VM) / cloud-init (`no signature`_!)
  - [x] `debootstrap`_
  - [x] `debuerreotype`_

- [x] Create docker image

  - [x] `apt-cacher-ng`_
  - [x] `debian image`_
  - [x] `debuerreotype image`_

- [x] Create VM environment

  - [x] Pool

    - [x] ``directory``
    - [ ] ``lvg``

  - [x] Network

    - [x] Natted

      - [x] dhcp
      - [x] static

    - [ ] Routed

  - [x] Disk

    - [x] Types

      - [x] ``ext4`` on ``qcow2`` (``directory`` pool)
      - [x] ``lv`` on ``qcow2`` (``directory`` pool)
      - [ ] ``lv`` on ``lv`` (``lvg`` pool)

    - [x] Bootloader

- [x] Create VM

  - [x] `virt-install`_

    - [x] imported disk
    - [ ] `kickstart file`_

  - [ ] `virt-builder`_
  - [ ] `virt-bootstrap`_

- [x] Provision VM

  - [x] `virt-sysprep`_
  - [x] `ansible`_

- [ ] Clone VM

  - [ ] volume copy + `virt-sysprep`_ (filesystem `uuids broken`_!)
  - [ ] volume file tar + create image + `virt-sysprep`_
  - [ ] `virt-clone`_

- [ ] Builder VM (`ansible libvirt`_ / `ansible docker`_)

  - [ ] Create debian rootfs
  - [ ] Create docker image
  - [ ] Create VM environment
  - [ ] Create VM
  - [ ] Clone VM

.. _netinst iso:         https://www.debian.org/distrib/netinst
.. _cloud image:         https://cloud.debian.org/images/cloud

.. _debian image:        https://hub.docker.com/_/debian
.. _debuerreotype image: https://hub.docker.com/r/debuerreotype/debuerreotype

.. _ansible:             https://docs.ansible.com/ansible/latest
.. _ansible libvirt:     https://docs.ansible.com/ansible/latest/collections/community/libvirt
.. _ansible docker:      https://docs.ansible.com/ansible/latest/collections/community/docker

.. _no signature:
   https://cloud.debian.org/images/cloud/
.. _kickstart file:
   https://manpages.debian.org/testing/virtinst/virt-install.1.en.html#--initrd-inject
.. _uuids broken:
   https://manpages.debian.org/testing/guestfs-tools/virt-sysprep.1.en.html#fs-uuids

**Ansible:**

The provided ansible playbook is an example for both basic debian configuration and flavour.
It includes tasks for

- system

  - environment (set stage info)
  - host (set hostname and ``/etc/hosts``)
  - network (configure interfaces)
  - packages (configure apt proxy, update/upgrade/reboot, install/remove packages)
  - locales (set timezone/LANG)
  - users (add/configure admin users, add/remove ssh keys)
  - terminal (add terminfos)
  - shell (add zsh, add grml/local config)

- sshd

  - configuration (sane default)
  - motd (stats)


**Security:**

The provided scripts bootstrap everything with debootstrap and a keyring as root of trust.
This keyring is generated and verified by

- A pinned sign key for the keyring package
- A pinned signed package dsc file for the keyring package
- The sha256sum for the keyring package included in the dsc file
- Additional checks during the make process of the keyring package

Other considerations:

- Debuerreotype generates the widely used official docker hub debian images.
  They are not official debian releases, but debuerreotype is maintained by two
  debian maintainers and they are reproducible.
- The reproducibility can be checked via shasum for each build in
  ``./scripts/debuerreotype/builds/build.sha256.log``
  (buildpath, shasum for included/excluded packages, shasums for normal/slim build)
- The debuerreotype build folder is mounted into the debuerreotype container
  (defaults to the repository folder)
- The debuerreotype image will add capacities ``SYS_ADMIN`` and drop ``SETFCAP`` in
  order to be able to fuse mount.
- The initial libvirt VM password is passed via parameter
- The provided sshd/ssh keys are obviously not secure and should not be used beyond testing

**Todo:**

- Add swap partition to libvirt storages
- Add lvg pool capability
- Add libvirt pool name as subfolder in ``./scripts/libvirt/image/NAME``
  (or omit the whole intermediate image step)
- Build and clone libvirt VM templates
- Better handling of different libvirt networks
- Bootstrap a builder VM and try to replace/trigger bash scripts with an ansible role
- Try to use debuerreotype scripts without docker environment and ``examples/debian.sh``
  (better parametrization, omit unneccessary builds)
- Remove verification of sha512sum of keyring package
  (now that the dsc file and sign key is pinned)
- Add generation script for ssh/sshd keys


Files
-----
::

    .
    ├── docs/                              - rendered documentation
    │   ├── build.sh                       - script to render README.rst as HTML
    │   ├── styles.css                     - stylesheet for documentation
    │   └── README.html                    - rendered README.rst
    │
    ├── tests/                             - test scripts
    │   ├── SUITE-docker.sh                - docker test (build/import/run)
    │   ├── SUITE-libvirt.sh               - libvirt test (build/connect)
    │   └── SUITE-ansible.sh               - ansible test (build/provision/connect)
    │
    ├── scripts/                           - script collection
    │   ├── apt-cacher-ng/                 - apt cacher ng scripts
    │   │   ├── cache/                     - cache folder mounted in the container
    │   │   ├── log/                       - log folder mounted in the container
    │   │   │
    │   │   ├── Dockerfile                 - Dockerfile for apt-cacher-ng service
    │   │   ├── entrypoint.sh              - docker entrypoint
    │   │   │
    │   │   ├── build.sh                   - build image
    │   │   ├── start.sh                   - start service
    │   │   ├── stop.sh                    - stop service
    │   │   └── clean.sh                   - clean artifacts
    │   │
    │   ├── debootstrap/                   - debootstrap scripts
    │   │   ├── upstream/                  - debootstrap subrepo (upstream)
    │   │   ├── cache/                     - cache folder mounted in the chroot
    │   │   ├── keyrings/                  - downloaded keyrings
    │   │   │   ├── *.json                 - responses from package api
    │   │   │   ├── *.sha512               - checksums for keyring packages
    │   │   │   ├── *.gpg                  - sign keys for dsc files
    │   │   │   └── *.dsc                  - signed keyring package descriptions
    │   │   │
    │   │   ├── builds/SUITE/rootfs        - generated rootfs
    │   │   │
    │   │   ├── build.sh                   - build debootstrap rootfs
    │   │   └── clean.sh                   - clean artifacts
    │   │
    │   ├── debuerreotype/                 - debuerrotype scripts
    │   │   ├── upstream/                  - debuerreotype subrepo (upstream)
    │   │   ├── patches/                   - patches for debuerreotype scripts
    │   │   │
    │   │   ├── builds/
    │   │   │   ├── BACKEND/SERIAL/ARCH/SUITE/
    │   │   │   │   ├── slim/rootfs.tar.gz - slim version of rootfs
    │   │   │   │   └── rootfs.tar.gz      - rootfs
    │   │   │   └── build.sha256.log       - log of reproducible build shasums
    │   │   │
    │   │   ├── bootstrap.sh               - bootstrap a debuerrotype docker image
    │   │   ├── build.sh                   - build debian rootfs
    │   │   └── clean.sh                   - clean artifacts
    │   │
    │   ├── docker/                        - docker scripts
    │   │   ├── build.sh                   - build debian docker image
    │   │   └── clean.sh                   - clean artifacts
    │   │
    │   ├── libvirt/                       - libvirt scripts
    │   │   ├── image/                     - image directory
    │   │   ├── interface/                 - files for interface configuration
    │   │   │   ├── dhcp                   - dhcp configuration
    │   │   │   └── static                 - static ip configuration
    │   │   ├── pool/NAME/                 - pool directory
    │   │   ├── ssh/                       - ssh files
    │   │   │   ├── libvirtlocal(.pub)     - ssh client test key
    │   │   │   └── ssh_host_*_key(.pub)   - ssh server test keys
    │   │   ├── xml/                       - generated xml definitions
    │   │   │
    │   │   ├── create_domain.sh           - create domain
    │   │   ├── create_image.sh            - create image
    │   │   ├── create_network.sh          - create network
    │   │   ├── create_pool.sh             - create pool
    │   │   ├── create_volume.sh           - create volume
    │   │   │
    │   │   ├── build.sh                   - build libvirt VM
    │   │   └── clean.sh                   - clean artifacts
    │   │
    │   └── ansible/                       - ansible playbook
    │       ├── group_vars/                - group variables
    │       │   └── all.yml                - group variables for all hosts
    │       ├── roles/                     - roles
    │       │   ├── system/                - basic debian system provisioning
    │       │   └── sshd/                  - sshd service configuration
    │       │
    │       ├── ansible.cfg                - configuration
    │       └── debian.yml                 - playbook
    │
    ├── README.rst                         - this readme
    ├── LICENCE.txt                        - the license for this repository
    │
    ├── .project.sh                        - base script sourced by all other scripts
    │
    ├── build.sh                           - main build script (libvirt + ansible)
    └── clean.sh                           - clean artifacts


Installation
------------

Requirements

- `debootstrap`_
- `docker`_
- `libvirt`_
- `virt-manager`_
- `libguestfs-tools`_
- `sipcalc`_
- `ansible`_

.. _sipcalc: http://www.routemeister.net/projects/sipcalc/

Install requirements

- Debian
  ::

      # Debian
      sudo apt-get install \
          debootstap jetring gnupg2 \
          docker.io \
          libvirt-daemon-system qemu-system \
          virt-manager virt-viewer virtinst \
          libguestfs-tools \
          sipcalc \
          ansible

- Archlinux
  ::

      sudo pacman -S \
          debootstap jetring gnupg \
          docker \
          libvirt qemu-base iptables-nft dnsmasq dmidecode openbsd-netcat \
          virt-manager virt-viewer \
          libguestfs guestfs-tools \
          sipcalc \
          ansible

Checkout this repo and subrepos
::

    git clone <URL>
    git submodule update --init --recursive

Add the hosts to ``/etc/hosts``, e.g. for the test scripts
::

    # debian image builder
    192.168.100.101		bullseye-libvirt.test
    192.168.100.111		bullseye-ansible.test
    192.168.100.102		bookworm-libvirt.test
    192.168.100.112		bookworm-ansible.test

Add the ssh key (no passphrase) to your ssh agent
::

    cp ./libvirt/ssh/libvirtlocal* ~/.ssh/
    ssh-add ~/.ssh/libvirtlocal

If you use a firewall, adjust the rules for the vm network, e.g. nftables
::

    chain input {
        [...]

        # libvirt
        iifname "virbr-*" ip saddr 192.168.100.0/24 ip daddr 192.168.100.1 \
            accept comment "allow libvirt host communication"
        iifname "virbr-*" ip protocol udp ip saddr 0.0.0.0 ip daddr 255.255.255.255 \
            accept comment "allow libvirt dns broadcast"

        [...]
        # log
    }
    chain forward {
        [...]

        # docker
        ip saddr 172.17.0.0/12 ip daddr 172.17.0.0/12 \
            accept comment "allow docker subnet commmunication"
        oifname enp14s0 ip saddr 172.17.0.0/12 \
            accept comment "allow docker internet commmunication out"
        iifname enp14s0 ip daddr 172.17.0.0/12 \
            accept comment "allow docker internet commmunication in"

        # libvirt
        ip saddr 192.168.100.0/24 ip daddr 192.168.100.0/24 \
            accept comment "allow libvirt subnet communication"
        iifname "virbr-*" ip saddr 192.168.100.0/24 \
            accept comment "allow libvirt communication out"
        oifname "virbr-*" ip daddr 192.168.100.0/24 \
            accept comment "allow libvirt communication in"

        [...]
        # log
    }


Build HTML documentation including the synopsis of the scripts (``--help``)
::

    ./docs/build.sh
    xdg-open docs/README.html


Usage
-----

docker
''''''

Build and run a bookworm docker image ``debian:bookworm-slim`` via test script
::

    ./tests/bookworm-docker.sh

Build and run a custom bookworm docker image ``my-bookworm``
::

    ./scripts/docker/build.sh bookworm my-bookworm
    docker run --rm -it my-bookworm bash

libvirt
'''''''

*Note: By default a libvirt network "debian" in range 192.168.100.0/24
and interface "virt-debian" are created.*

Build and run a minimal bookworm libvirt VM ``bookworm-libvirt.test``
on ``192.168.100.102`` via test script
::

    ./tests/bookworm-libvirt.sh

Build and run a custom minimal bookworm libvirt VM ``my-bookworm-libvirt.test`` on dhcp:

1. Run the build script
   ::

        ./scripts/libvirt/build.sh --domain-name my-bookworm-libvirt.test bookworm

2. Fetch the IP of the VM
   ::

        virsh net-dhcp-leases debian

3. Connect to the VM
   ::

        ssh root@<IP>

4. Delete the VM
   ::

        virsh destroy my-bookworm-libvirt.test
        virsh undefine my-bookworm-libvirt.test
        rm ./scripts/libvirt/image/my-bookworm-libvirt.test.lvm.ext4.qcow2
        rm ./scripts/libvirt/pool/develop/my-bookworm-libvirt.test.lvm.ext4.qcow2

ansible
'''''''

*Note: By default a libvirt network "debian" in range 192.168.100.0/24
and interface "virt-debian" are created.*

Build and run an ansible provisioned bookworm libvirt VM ``bookworm-ansible.test``
on ``192.168.100.112`` via test script
::

    ./examples/bookworm-ansible.sh

Build and run a custom ansible provisioned bookworm libvirt VM ``my-bookworm-ansible.test``
on ``192.168.100.50``:

1. Add the host to ``/etc/hosts``
   ::

        # debian image builder
        192.168.100.50		my-bookworm-ansible.test

2. Run the build script
   ::

        ./build.sh --suite bookworm my-bookworm-ansible.test 192.168.100.50

3. Connect to the VM
   ::

        ssh admin@my-bookworm-ansible.test
        ssh root@my-bookworm-ansible.test

4. Delete the VM
   ::

        virsh destroy my-bookworm-ansible.test
        virsh undefine my-bookworm-ansible.test
        rm ./scripts/libvirt/image/my-bookworm-ansible.test.lvm.ext4.qcow2
        rm ./scripts/libvirt/pool/develop/my-bookworm-ansible.test.lvm.ext4.qcow2

Manually run the ansible playbook
::

    ansible-playbook \
        --timeout 100 \
        --inventory my-bookworm-ansible.test, \
        --user root \
        --tags setup \
        scripts/ansible/debian.yml

Manually run a system upgrade via the ansible playbook
::

    ansible-playbook \
        --timeout 100 \
        --inventory my-bookworm-ansible.test, \
        --user root \
        --tags upgrade \
        scripts/ansible/debian.yml

clean
'''''

Clean artifacts (custom domains need to be undefined manually)
::

    # all (calls all scripts below)
    ./clean.sh

    # libvirt
    ./scripts/libvirt/clean.sh
    # docker
    ./scripts/docker/clean.sh
    # debuerreotype
    ./scripts/debuerreotype/clean.sh
    # debootstrap
    ./scripts/debootstrap/clean.sh


Scripts
-------

.. include:: docs/usages.rst


License
-------

::

    debian-image-builder -- Build/Provision debian images for docker/libvirt
    Copyright (C) 2023 Alexander Blum <workispleasure@pleasureiswork.net>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.


Appendix
--------

debootstrap
'''''''''''

**Description:**

- generates a basic debian rootfs
- written in bash
- has minimal dependencies (``wget``)

Usage
`````

Generate base rootfs with default host keyring
::

    debootstrap bullseye rootfs

Generate minbase rootfs with custom keyring and cache folder
::

    debootstrap \
        --cache-dir=cache \
        --keyring=debian-keyring.gpg --force-check-gpg \
        --variant=minbase \
        bullseye rootfs

Keyring
```````

Generate keyring

- Via host package (``/usr/share/keyrings/debian-keyring.gpg``)
  ::

      apt-get install debian-keyring

- Via rsync (no checksums/signature, but up-to-date)
  ::

      rsync -az --progress keyring.debian.org::keyrings/keyrings/ .

- Via debian archive (choose package for suite)
  ::

      mirror=http://deb.debian.org/
      keyring=debian-keyring_2021.07.26

      # Fetch package
      wget -q $mirror/debian/pool/main/d/debian-keyring/$keyring.tar.gz

      # Compare with prepared pinned checksum
      sha512sum --quiet --strict --check $keyring.tar.gz.sha512

      # Generate keyring and verify signature
      tar -xf $keyring.tar.gz
      cd ${keyring//_/-}
      make --silent -j1

Links
`````

- debootstrap

  - `Wiki`__
  - `Manpage`__
  - `Source`__
  - `Tutorial (debian.org)`__
  - `Tutorial (linux-sunxi.org)`__
  - `Tutorial (aguslr.com)`__
  - `Tutorial (gist.github.com/Lakshimipathi)`__

- keyrings

  - `Wiki`__
  - `Signing Keys`__
  - `Tutorial`__

__ https://wiki.debian.org/Debootstrap
__ https://manpages.debian.org/bullseye-backports/debootstrap/debootstrap.8.en.html
__ https://salsa.debian.org/installer-team/debootstrap
__ https://www.debian.org/releases/stable/amd64/apds03.en.html
__ https://linux-sunxi.org/Debootstrap
__ https://aguslr.com/blog/2019/03/24/lightweight-debian.html
__ https://gist.github.com/Lakshmipathi/81fe57c9507304fa5adbaa4fb2feaed7

__ https://wiki.debian.org/DebianKeyring
__ https://ftp-master.debian.org/keys.html
__ https://www.boddie.org.uk/david/www-repo/Documents/qemu-debootstrap-raspbian.html


debuerreotype
'''''''''''''

**Description:**

- provides a set of scripts to generate and optimize reproducible rootfs builds,
  described in its `README <https://github.com/debuerreotype/debuerreotype#usage>`_
- provides generic example build scripts for debian, ubuntu and others
- provides a Dockerfile and docker run script to execute the build scripts within
  a clean build environment
- written in bash
- depends on

  - `debootstrap`_ in an executable path
  - ``dpkg`` in an executable path (so it needs debian as environment)

Usage
`````

*Note: For a list of all arguments/flags, execute the scripts with the ``--help`` flag.*

Minimal example run on host to build a current snapshot bookworm
::

    debuerreotype-init /tmp/rootfs bookworm now
    debuerreotype-debian-sources-list /tmp/rootfs bookworm
    debuerreotype-tar /tmp/rootfs rootfs.tar.gz

Minimal example run on host to build a certain snapshot of bookworm
::

    debuerreotype-init /tmp/rootfs bookworm 2023-03-01T00:00:00Z
    debuerreotype-debian-sources-list /tmp/rootfs bookworm
    debuerreotype-tar /tmp/rootfs rootfs.tar.gz

Minimal example run on host to build a non-snapshot bookworm
::

    debuerreotype-init --non-debian /tmp/rootfs bookworm http://debian.org/debian
    debuerreotype-debian-sources-list /tmp/rootfs bookworm
    debuerreotype-tar /tmp/rootfs rootfs.tar.gz

Minimal snapshot example run in docker to build a specific snaphot of bookworm
::

    ./docker-run.sh sh -euxc "
        debuerreotype-init /tmp/rootfs bookworm 2023-03-01T00:00:00Z;
        debuerreotype-debian-sources-list /tmp/rootfs bookworm;
        debuerreotype-tar /tmp/rootfs rootfs.tar.xz
    "

Execution of debian example file in docker
::

    ./docker-run.sh sh -euxc "
        ./debuerreotype/examples/debian.sh builds bookworm 2023-03-01T00:00:00Z
    "

The gist of the debian example file
::

    debuerreotype-init [...] "$rootfsDir" "$suite" "@$epoch"
    debuerreotype-debian-sources-list [...] --snapshot "$rootfsDir" "$suite"
    debuerreotype-minimizing-config "$rootfsDir"
    debuerreotype-apt-get "$rootfsDir" update -qq
    debuerreotype-apt-get "$rootfsDir" full-upgrade -yqq
    debuerreotype-slimify "$rootfsDir"-slim
    debuerreotype-debian-sources-list [...] "$rootfs" "$suite"
    debuerreotype-tar [...] "$rootfs" "$targetBase.tar.xz"

Cache
`````

Use apt-cacher-ng
::

    # using docker image for builds on host/docker
    proxyIp="$(docker exec $cacheImageName sh -c "hostname --ip-address")"
    export http_proxy="http://$proxIp:3142"

    # using local service for builds on host/docker
    export http_proxy="http://127.0.0.1:3142"

Export
``````

Export into docker
::

    xz -cd rootfs.tar.gz | docker import - debian:bookworm-slim

Export into qcow2
::

    virt-make-fs --format=qcow2 --size=1G --partition=mbr --type=ext4 \
        rootfs.tar image.qcow2

Checksums
`````````

Verify checksums

- folder -> tar
  ::

      echo "sha256:$(tar -cC rootfs . | sha256sum - | cut -d' ' -f1)"

- tar
  ::

      echo "sha256:$(sha256sum rootfs.tar | cut -d' ' -f1)"

- tar.gz -> tar
  ::

      echo "sha256:$(xz -cd rootfs.tar.gz | sha256sum - | cut -d' ' -f1)"

- docker first layer = tar
  ::

      docker image inspect --format "{{index (.RootFS.Layers) 0}}" \
          debian:bookworm-slim

- vm filesystem -> tar
  ::

      mkdir rootfs
      touch --no-dereference --date="@$(date -r image.qcow2 +%s)" rootfs
      virt-tar-out -a image.qcow2 / rootfs.indeterministic.tar
      tar --extract --file rootfs.indeterministic.tar --directory rootfs
      tar --create --file rootfs.deterministic.tar --auto-compress \
          --directory rootfs --exclude "lost+found" --numeric-owner \
          --transform 's,^./,,' --sort name .
      echo "sha256:$(sha256sum rootfs.deterministic.tar | cut -d' ' -f1)"

Diff tarballs
::

    diffoscope source.tar target.tar

Differences
```````````

- debuerrotype specific

  - ``hostname``: empty or set to ``debuerreotype`` (random on docker start)
  - ``resolve.conf``: ``1.1.1.1`` / ``1.0.0.1`` (host settings on docker start)
  - during bootstrap: apt with ``Acquire::Check-Valid-Until=false``

- docker specific

  - minimize config

    - [+] ``/sbin/initctl`` -> exit 0 (only for upstart)
    - [+] ``/usr/sbin/policy-rc.d`` -> exit 101
    - [+] ``/etc/dpkg/dpkg.cfg.d/docker-apt-speedup``
    - [+] ``/etc/apt/apt.conf.d/docker-autoremove-suggests``
    - [+] ``/etc/apt/apt.conf.d/docker-clean``
    - [+] ``/etc/apt/apt.conf.d/docker-gzip-indexes``
    - [+] ``/etc/apt/apt.conf.d/docker-no-languages``

  - slimify

    - [+] ``/etc/dpkg/dpkg.cfg.d/docker``
    - [-] ``/usr/share/man/man[0-9]``
    - [-] ``/var/log/dpkg.log``
    - [-] ``/var/log/bootstrap.log``
    - [-] ``/var/log/alternatives.log``
    - [-] ``/var/cache/ldconfig/aux-cache``
    - [-] also see files ``.slimify-excludes|includes``

- revert the changes

  - set ``hostname``
  - set ``resolve.conf``
  - delete

    - ``/usr/sbin/policy-rc.d``
    - ``/etc/dpkg/dpkg.cfg.d/docker*``
    - ``/etc/apt/apt.conf.d/docker*``

  - update (to regenerate man files)

- sizes

  - docker image: 81M (tar.xz)
  - libvirt qcow2: 985M

Links
`````

- `Source`__
- `Debuerreotype Docker Image`__
- `Debian Docker Image`__

__ https://github.com/debuerreotype/debuerreotype
__ https://hub.docker.com/r/debuerreotype/debuerreotype
__ https://hub.docker.com/_/debian


libvirt
'''''''

**Description:**

- is a toolkit to manage virtualization platforms
- supports KVM, Hypervisor.framework, QEMU, Xen, Virtuozzo, VMWare ESX, LXC, BHyve and more
- written in C, bindings in many languages (python, C#, ...)

**Services:**

- ``libvirtd.service``
- ``virtlogd.service``

**Paths:**

- config

  - ``/etc/libvirt``
  - ``/var/lib/libvirt``

- network

  - ``/etc/libvirt/<hypervisor>/networks/``

- storage

  - ``/var/lib/libvirt/images/`` (system)
  - ``~/VirtualMachines`` (session)

- hooks

  - ``/etc/libvirt/hooks``

- logs

  - ``/var/log/libvirt/qemu``
  - ``/var/log/libvirt/libvirtd.log``

**Logging:**
::

    vi /etc/libvirt/libvirtd.conf
        log_level = 1
        log_outputs="1:file:/var/log/libvirt/libvirtd.log"
    service libvirtd restart

Connection
``````````
::

    # virsh @ local system
    virsh -c qemu:///system

    # virsh @ local session
    virsh -c qemu:///session

    # virsh @ remote system
    virsh -c qemu+ssh://<user>@<host>/system

    # virsh @ remote system with debugging
    [LIBVIRT_DEBUG=1] virsh -c qemu+ssh://<user>@<host>/system

    # virt-viewer @ remote system
    virt-viewer  --connect qemu+ssh://<user>@<host>/system domain

    # virt-viewer @ remote system
    virt-manager --connect qemu+ssh://<user>@<host>/system domain

Enable VNC:
::

    virsh shutdown DOMAIN
    virsh edit DOMAIN
        <devices>
          [...]
          <graphics type='vnc' port='-1' autoport='yes' listen='0.0.0.0|127.0.0.1'>
            <listen type='address' address='0.0.0.0|127.0.0.1'/>
          </graphics>
          [...]
        </devices>

Enable Console:
::

    virsh shutdown DOMAIN
    virsh edit DOMAIN
        <devices>
          [...]
          <console type='pty'>
            <target type='serial' port='0'/>
          </console>
          [...]
        </devices>

virsh
`````
::

      # host
      nodeinfo

      # info
      list [--all]
      dominfo DOMAIN
      console DOMAIN [--force]
          Strg+5 exit
          Ctrl+] host

      # management
      define XMLFILE
      create XMLFILE
      migrate DOMAIN URI
      save DOMAIN FILE
      restore FILE

      # lifecycle
      start DOMAIN
      autostart [--disable] DOMAIN
      reboot DOMAIN
      shutdown DOMAIN
      suspend DOMAIN
      resume DOMAIN
      destroy DOMAIN
      undefine DOMAIN --remove-all-storage

      # configuration
      dumpxml DOMAIN
      edit DOMAIN
      setmem DOMAIN SIZE
      setcpus DOMAIN AMOUNT
      attach-disk DOMAIN SOURCE TARGET [--persistent]
      detach-disk DOMAIN TARGET [--persistent] [--live]

      # volumes
      pool-list [--all]
      pool-refresh POOL
      pool-create-as DOMAIN TYPE [SRCHOST] [SRCPATH] [SRCDEV] [SRCNAME] [TARGET]
      pool-define-as DOMAIN TYPE [SRCHOST] [SRCPATH] [SRCDEV] [SRCNAME] [TARGET]
      pool-build POOL
      pool-start POOL
      pool-autostart POOL
      pool-undefine POOL
      vol-list POOL
      vol-create-as POOL FILE SIZE
      vol-delete IMAGE [--pool POOL]
      vol-wipe IMAGE

      # snapshots
      snapshot-list DOMAIN
      snapshot-info DOMAIN [--snapshotname SNAPSHOT]
      snapshot-create-as DOMAIN [--name NAME] [--description DESCRIPTION]
                                [--disk-only] [--atomic]
      snapshot-revert DOMAIN [--snapshotname SNAPSHOT] [--running]
      snapshot-delete DOMAIN [--snapshotname SNAPSHOT]

      # network
      net-list [--all]
      net-dumpxml NETWORK
      net-define XMLFILE
      net-create XMLFILE
      net-undefine NETWORK
      net-start NETWORK
      net-autostart NETWORK
      net-destroy NETWORK
      net-dhcp-leases NETWORK
      domifaddr --source agent DOMAIN (qemo-guest-agent!)

      # persist trasient objects created with `*-create`
      OBJECTTYPE-dumpxml OBJECTNAME > OBJECTNAME.xml
      OBJECTTYPE-define OBJECTNAME.xml

Network
```````

Network bridge with NAT:
::

    # copy xml from default net
    virsh net-dumpxml default > br1.xml
    # or create new xml
    vi br1.xml
        <network>
          <name>br1</name>
          <forward mode='nat'>
            <nat>
              <port start='1024' end='65535'/>
            </nat>
          </forward>
          <bridge name='br1' stp='on' delay='0'/>
          <ip address='192.168.100.1' netmask='255.255.255.0'>
            <dhcp>
              <range start='192.168.100.10' end='192.168.100.100'/>
            </dhcp>
          </ip>
        </network>

    # add bridge
    virsh net-define br1.xml
    virsh net-start br1
    virsh net-autostart br1
    # check bridge is added
    virsh net-list --all
    bridge link
    ip addr show dev br1
    # attach guest
    virsh attach-interface --domain DOMAIN --type bridge \
        --source br1 --model virtio --config --live
    # check attachment
    virsh domiflist DOMAIN

    # detach guest
    virsh detach-interface --domain DOMAIN --type bridge --mac MAC --config
    # check detachment
    virsh domiflist DOMAIN
    # remove bridge
    virsh net-destroy br1
    virsh net-undefine br1
    # check bridge is removed
    virsh net-list --all
    bridge link
    ip addr show dev br1

Network bridge without NAT:
::

    # add bridge
    ip link add name br1 type bridge
    ip link set dev br1 up
    ip link set eth0 up
    ip link set eth0 masterbr1
    # check bridge
    bridge link

    # remove bridge
    ip link set eth0 nomaster
    ip link set eth0 down
    ip link delete br1 type bridge
    # check bridge
    bridge link

Pool
````

Create a new pool:
::

    virsh pool-define-as POOL type [source-host] [source-path] [source-dev]
                                   [source-name] [<target>] [--source-format format]
    virsh pool-define-as POOL dir - - - - /home/username/.local/libvirt/images
    virsh pool-define-as POOL fs - -  /dev/vg0/images - mntpoint
    virsh pool-build     POOL  # warning: destructive operation
    virsh pool-start     POOL
    virsh pool-autostart POOL


Links
`````

- qemu

  - `Qemu Documentation`__
  - `Qemu: System vs Session (wikichoon.com)`__

  __ https://www.qemu.org/docs/master/index.html
  __ https://blog.wikichoon.com/2016/01/qemusystem-vs-qemusession.html

- libvirt

  - `Homepage`__
  - `Bindings`__
  - `Bindings (Python)`__
  - `Wiki (archlinux.org)`__
  - `Xml Specification`__
  - `Xpath Cheatsheet (devhints.io)`__
  - `Tutorial (debian-handbook.info)`__
  - `Tutorial: Nested KVM`__

  __ https://libvirt.org/
  __ https://libvirt.org/bindings.html
  __ https://libvirt.org/docs/libvirt-appdev-guide-python/en-US/html/
  __ https://wiki.archlinux.org/title/Libvirt
  __ https://libvirt.org/formatdomain.html
  __ https://devhints.io/xpath
  __ https://debian-handbook.info/browse/stable/sect.virtualization.html#id-1.15.5.16
  __ https://www.howtogeek.com/devops/how-to-enable-nested-kvm-virtualization/

- virsh

  - `Manpage`__
  - `Cheatsheet (computingforgeeks.com)`__
  - `Introduction (thomas-krenn.com)`__
  - `Introduction (adamtheautomator.com)`__
  - `Documentation (redhat.com)`__
  - `Documentation (suse.com)`__

  __ https://manpages.debian.org/bullseye/libvirt-clients/virsh.1.en.html
  __ https://computingforgeeks.com/virsh-commands-cheatsheet/
  __ https://www.thomas-krenn.com/de/wiki/Virsh_-_Kommandozeilenwerkzeug_zur_Verwaltung_virtueller_Maschinen
  __ https://adamtheautomator.com/virsh/
  __ https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/5/html/virtualization/chap-virtualization-managing_guests_with_virsh
  __ https://documentation.suse.com/sles/15-SP1/html/SLES-all/cha-libvirt-config-virsh.html

- network

  - `Documentation Basics`__
  - `Documentation Full`__
  - `Handbook (jamielinux.com)`__
  - `Tutorial (computingforgeeks.com)`__

  __ https://wiki.libvirt.org/VirtualNetworking.html#basic-command-line-usage-for-virtual-networks
  __ https://wiki.libvirt.org/VirtualNetworking.html
  __ https://jamielinux.com/docs/libvirt-networking-handbook/
  __ https://computingforgeeks.com/managing-kvm-network-interfaces-in-linux/

- pool

  - `Documentation`__
  - `Tutorial: LVM (redhat.com)`__

  __ https://libvirt.org/storage.html
  __ https://access.redhat.com/documentation/de-de/red_hat_enterprise_linux/6/html/virtualization_administration_guide/create-lvm-storage-pool-virsh

- disk

  - `Documentation`__
  - Installation

    - Tutorial: Debootstrap + Qemu

      - `Image Creation (packtpub.com)`__
      - `Image Provisioning (packtpub.com)`__

    - `Tutorial: Netinst Iso + Manual Installation (server-world.info)`__
    - `Example: Netinst Iso + Kickstart file (github.com/pin)`__
    - `Tutorial: Cloud Iso + Manual Installation (techviewleo.com)`__
    - `Answer: Debootstrap + virt-make-fs (serverfault.com)`__
    - `Answer: Debootstrap + guestfish (serverfault.com)`__

  - Bootloader

    - `Wiki`__
    - `Documentation: Host Bootloader (redhat.com)`__

  __ https://libvirt.org/kbase/backing_chains.html
  __ https://subscription.packtpub.com/book/virtualization-and-cloud/9781788294676/1/ch01lvl1sec12/preparing-images-for-os-installation-with-qemu-nbd
  __ https://subscription.packtpub.com/book/virtualization-and-cloud/9781788294676/1/ch01lvl1sec13/installing-a-custom-os-on-the-image-with-debootstrap
  __ https://www.server-world.info/en/note?os=Debian_11&p=kvm&f=2
  __ https://github.com/pin/debian-vm-install
  __ https://techviewleo.com/run-debian-11-bullseye-on-kvm-using-qcow2-cloud-image/
  __ https://serverfault.com/a/916697
  __ https://serverfault.com/a/977649
  __ https://wiki.debian.org/BootLoader
  __ https://access.redhat.com/documentation/de-de/red_hat_enterprise_linux/6/html/virtualization_administration_guide/sub-sect-op-sys-host-boot

- console

  - `Documentation`__
  - `Tutorial (ravada.readthedocs.io)`__
  - `Tutorial (gist.github.com/lukasnellen)`__
  - `Tutorial (zapletalovi.com)`__

  __ https://wiki.libvirt.org/LibvirtConsoleManagement.html
  __ https://ravada.readthedocs.io/en/latest/docs/config_console.html
  __ https://gist.github.com/lukasnellen/fe9b61cb9add581ef0215bd40c09c7c2
  __ https://lukas.zapletalovi.com/posts/2021/enable-serial-console-in-libvirt/


virt-manager
''''''''''''

**Description:**

- ``virt-manager`` is a desktop user interface for managing virtual machines through libvirt.
- ``virt-viewer`` is a lightweight UI interface for interacting with the graphical display
  of virtualized guest OS. It can display VNC or SPICE, and uses libvirt to lookup the
  graphical connection details.
- ``virt-install`` is a command line tool which provides an easy way to provision operating
  systems into virtual machines.
- ``virt-clone`` is a command line tool for cloning existing inactive guests. It copies the
  disk images, and defines a config with new name, UUID and MAC address pointing to the
  copied disks.
- ``virt-xml`` is a command line tool for easily editing libvirt domain XML using
  virt-install’s command line options.
- ``virt-bootstrap`` is a command line tool providing an easy way to setup the root file
  system for libvirt-based containers.

virt-manager
````````````
::

    virt-manager --connect qemu:///system
    virt-manager --connect qemu+ssh://<user>@<host>/system domain

virt-viewer
```````````
::

    virt-viewer  --connect qemu:///system
    virt-viewer  --connect qemu+ssh://<user>@<host>/system domain


virt-install
````````````
::

    # notation
    --option
        example1
        example2

    # minimum
    --name
    --memory
    --disk|filesystem|nodisks

    # host
    --connect URI
        qemu:///system
        qemu:///session

    # domain
    --name DOMAIN
        test
    --cpu CPU
        host
    --virt-type TYPE
        kvm
    --memory/--ram SIZE
        4096
    --vcpus AMOUNT[,OPTIONS]
        2
        2,maxvcpus=4
    --os-type TYPE
        Linux
    --os-variant VARIANT
        debian11
        # fetch via
        # $osinfo-query os --fields=short-id \
        #     vendor="Debian Project" codename="bookworm"
    --initrd-inject=FILE
        preseed.cfg
    --extra-args=KERNELOPTIONS
        auto=true hostname=HOSTNAME domain=DOMAIN console=tty0 \
            console=ttyS0,115200n8 serial
        console=ttyS0,115200n8 serial
    --hvm

    # boot
    --boot DEVICES
        cdrom,hd
        uefi,bootmenu.enable=on,bios.useserial=on

    # inject
    --initrd-inject=FILE
        ks.cfg
    + --extra-args="ks=file:/ks.cfg ..."

    # storage
    --location URL
        https://d-i.debian.org/daily-images/amd64/
        /home/debian-11.0.0-amd64-DVD-1.iso
    --disk FILE[,OPTIONS]
        image.qcow2,device=disk,bus=virtio,format=qcow2
        image.img,device=disk,bus=virtio,size=10,format=qcow2
        size=16,path=image.img,bus=virtio,cache=none
        path=image.img,size=20
        pool=testing,size=4
        size=8
    --disk PATH
    + --import

    # network
    --network NETWORK[,OPTIONS]
        network=default,model=virtio
        bridge=br0,mac=MAC,model=virtio
        bridge=br0
        user

    # periphery
    --controller CONTROLLER[,OPTIONS]
        usb,model=none

    # connections
    --graphics GRAPHICS[,OPTIONS]
        none
        vnc,listen=0.0.0.0
    --console CONSOLE[,OPTIONS]
        pty,target_type=serial
        pty,target_type=serial -x 'console=ttyS0,115200n8 serial'
    --noautoconsole

virt-clone
``````````
::

    virsh shutdown SOURCEDOMAIN
    sudo virt-clone \
        --connect=qemu:///system \
        --original SOURCEDOMAIN \
        --name TARGETDOMAIN \
        --file /var/lib/libvirt/images/IMAGE.qcow2
    ls /var/lib/libvirt/images
    virsh list --all
    vi /etc/libvirt/qemu/TARGETDOMAIN.xml
        <channel type='unix'>
            - <source mode='bind'
            -         path='.../domain-SOURCEDOMAIN/org.qemu.guest_agent.0'/>
            + <source mode='bind'
            +         path='.../domain-TARGETDOMAIN/org.qemu.guest_agent.0'/>
    virsh start TARGETDOMAIN --console
    > uuidgen eth0
    > vim /etc/sysconfig/network-scripts/ifcfg-eth0
          - UUID=<OLDUUID>
          + UUID=<NEWUID>
    > service network restart
    > systemctl restart network.service

Links
`````

- `Homepage`__
- virt-install

  - `Manpage`__
  - `Tutorial: virt-install Installation (p5r.uk)`__

- virt-clone

  - `Manpage`__
  - `Tutorial (computingforgeeks.com)`__
  - `Tutorial (level1techs.com)`__

- virt-xml

  - `Manpage`__

- virt-bootstrap

  - `Source`__

__ https://virt-manager.org/
__ https://manpages.debian.org/testing/virtinst/virt-install.1.en.html
__ https://p5r.uk/blog/2020/libvirt-vm-installation-over-serial-console.html
__ https://manpages.debian.org/bullseye/virtinst/virt-clone.1.en.html
__ https://computingforgeeks.com/how-to-clone-and-use-kvm-virtual-machine-in-linux/
__ https://forum.level1techs.com/t/best-practices-for-cloning-etc-libvirt-qemu-xmls/153792/8
__ https://manpages.debian.org/bullseye/virtinst/virt-xml.1.en.html
__ https://github.com/virt-manager/virt-bootstrap


libguestfs
''''''''''

**Description:**

- is a set of tools for accessing and modifying virtual machine (VM) disk images
- used for viewing and editing files inside guests, scripting changes to VMs,
  monitoring disk used/free statistics, creating guests, P2V, V2V, performing backups,
  cloning VMs, building VMs, formatting disks, resizing disks, etc
- is available through a scriptable shell called guestfish,
  or an interactive rescue shell virt-rescue
- has a 250 page manual
- written in C, bindings in many languages (python, C#, ...)

Commands
````````
::

    guestfs(3) — main API documentation
    guestfish(1) — interactive shell
    guestmount(1) — mount guest filesystem in host
    guestunmount(1) — unmount guest filesystem
    virt-alignment-scan(1) — check alignment of virtual machine partitions
    virt-builder(1) — quick image builder
    virt-builder-repository(1) — create virt-builder repositories
    virt-cat(1) — display a file
    virt-copy-in(1) — copy files and directories into a VM
    virt-copy-out(1) — copy files and directories out of a VM
    virt-customize(1) — customize virtual machines
    virt-df(1) — free space
    virt-dib(1) — safe diskimage-builder
    virt-diff(1) — differences
    virt-edit(1) — edit a file
    virt-filesystems(1) — display information about filesystems, devices, LVM
    virt-format(1) — erase and make blank disks
    virt-get-kernel(1) — get kernel from disk
    virt-inspector(1) — inspect VM images
    virt-list-filesystems(1) — list filesystems
    virt-list-partitions(1) — list partitions
    virt-log(1) — display log files
    virt-ls(1) — list files
    virt-make-fs(1) — make a filesystem
    virt-p2v(1) — convert physical machine to run on KVM
    virt-p2v-make-disk(1) — make P2V ISO
    virt-p2v-make-kickstart(1) — make P2V kickstart
    virt-rescue(1) — rescue shell
    virt-resize(1) — resize virtual machines
    virt-sparsify(1) — make virtual machines sparse (thin-provisioned)
    virt-sysprep(1) — unconfigure a virtual machine before cloning
    virt-tail(1) — follow log file
    virt-tar(1) — archive and upload files
    virt-tar-in(1) — archive and upload files
    virt-tar-out(1) — archive and download files
    virt-v2v(1) — convert guest to run on KVM

Usage
`````
::

    # filesystem operations
    virt-make-fs --format=FORMAT --type=TYPE [--site=[+]SIZE] FOLDER IMAGE
    virt-ls -l [-d DOMAIN | -a IMAGE] DIRECTORY
    virt-cat [-d DOMAIN | -a IMAGE] FILE
    virt-edit [-d DOMAIN | -a IMAGE] FILE
    virt-tar-out [-d DOMAIN | -a IMAGE] GUESTPATH TARFILE
    guestmount [-d DOMAIN | -a IMAGE] -i MOUNTPOINT [--ro|live]

    # information gathering
    virt-df [-d DOMAIN | -a IMAGE]
    virt-log [-d DOMAIN | -a IMAGE]
    virt-filesystems -l [-d DOMAIN | -a IMAGE]
                     [-h] [--partitions] [--all] [--long] [--uuid]

    # image provisioning
    virt-customize [-d DOMAIN | -a IMAGE]
                   --hostname HOSTNAME
                   --timezone TIMEZONE
                   --root-password USER:PASSWORD
                   --ssh-inject USER:file:PATH
                   --delete FILE
                   --link TARGET:LINK
                   --write PATH:CONTENT
                   --run-command COMMAND
    virt-sysprep [same parameters as virt-customize]
                 --operation OPERATION

Recipes
```````

Create partitioned image and import rootfs via guestfish
::

    guestfish <<EOF
    disk-create rootfs.qcow2 qcow2 "$((2 * $(stat -c%s rootfs.tar)))"
    add-drive rootfs.qcow2
    run
    part-disk /dev/sda gpt
    mkfs ext4 /dev/sda
    mount /dev/sda /
    tar-in rootfs.tar /
    umount-all
    exit
    EOF

Chroot into guest filesystem
::

    virsh shutdown DOMAIN
    guestmount -d DOMAIN -i /mnt
    chroot /mnt
    guestunmount /mnt


Links
`````

- `Homepage`__
- `FAQ`__
- `Library Background`__
- `Bindings`__
- `Bindings (Python)`__
- `Recipes`__
- Manpages

  - `guestfish`__
  - `virt-rescue`__
  - `virt-make-fs`__
  - `virt-builder`__
  - `virt-customize`__
  - `virt-sysprep`__
  - `virt-sysprep (default operations)`__

__ https://www.libguestfs.org/
__ https://www.libguestfs.org/guestfs-faq.1.html
__ https://www.libguestfs.org/guestfs-hacking.1.html
__ https://www.libguestfs.org/guestfs.3.html#using-libguestfs-with-other-programming-languages
__ https://www.libguestfs.org/guestfs-python.3.html
__ https://www.libguestfs.org/guestfs-recipes.1.html

__ https://www.libguestfs.org/guestfish.1.html
__ https://www.libguestfs.org/virt-rescue.1.html
__ https://www.libguestfs.org/virt-make-fs.1.html
__ https://www.libguestfs.org/virt-builder.1.html
__ https://www.libguestfs.org/virt-customize.1.html
__ https://www.libguestfs.org/virt-sysprep.1.html
__ https://www.libguestfs.org/virt-sysprep.1.html#operations

