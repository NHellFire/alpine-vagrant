#!/bin/ash
# abort this script when a command fails or a unset variable is used.
set -eu
# echo all the executed commands.
set -x

[ "$PACKER_BUILD_VERSION" = "edge" ] && echo http://dl-cdn.alpinelinux.org/alpine/edge/main > /etc/apk/repositories

ALPINE_VERSION=$(awk -F/ '/^https?:\/\/.*\/alpine\/.*?\/main$/ { print $(NF-1); exit}' /etc/apk/repositories)
if [ -z "$ALPINE_VERSION" ]; then
	echo "Failed to determine Alpine version"
	echo "Contents of /etc/apk/repositories:"
	cat /etc/apk/repositories
	exit 1
fi

# Enable community repo
echo http://dl-cdn.alpinelinux.org/alpine/$ALPINE_VERSION/community >>/etc/apk/repositories
# Enable testing if we're running edge
[ "$ALPINE_VERSION" = "edge" ] && echo http://dl-cdn.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories

# upgrade all packages.
apk upgrade -U --available

# add the vagrant user and let it use root permissions without sudo asking for a password.
apk add sudo
adduser -D vagrant
echo 'vagrant:vagrant' | chpasswd
adduser vagrant wheel
echo '%wheel ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/wheel

# add support for validating https certificates.
apk add ca-certificates openssl

# install the vagrant public key.
# NB vagrant will replace it on the first run.
install -d -m 700 /home/vagrant/.ssh
wget -qO /home/vagrant/.ssh/authorized_keys https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub
chmod 600 /home/vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant /home/vagrant/.ssh

# install the Guest Additions.
if [ "$(cat /sys/devices/virtual/dmi/id/board_name)" == 'VirtualBox' ]; then
# install the VirtualBox Guest Additions.
apk add -U virtualbox-guest-additions virtualbox-guest-modules-hardened
rc-update add virtualbox-guest-additions
echo vboxsf >>/etc/modules
modinfo vboxguest
else
# install the qemu-kvm Guest Additions.
apk add qemu-guest-agent
rc-update add qemu-guest-agent
# configure the GA_PATH, as, for some reason, its at /dev/vport0p1 instead of
# the expected /dev/virtio-ports/org.qemu.guest_agent.0.
# NB from the host, you can test whether qemu-ga is running on the guest with:
#       virsh qemu-agent-command $(cat .vagrant/machines/default/libvirt/id) '{"execute":"guest-ping"}' | jq
#       virsh qemu-agent-command $(cat .vagrant/machines/default/libvirt/id) '{"execute":"guest-info"}' | jq
sed -i -E 's,#?(GA_PATH=).+,\1"/dev/vport0p1",' /etc/conf.d/qemu-guest-agent
fi

# install the nfs client to support nfs synced folders in vagrant.
apk add nfs-utils

# disable the DNS reverse lookup on the SSH server. this stops it from
# trying to resolve the client IP address into a DNS domain name, which
# is kinda slow and does not normally work when running inside VB.
sed -i -E 's,#?(UseDNS\s+).+,\1no,' /etc/ssh/sshd_config

# use the up/down arrows to navigate the bash history.
# NB to get these codes, press ctrl+v then the key combination you want.
cat >>/etc/inputrc <<'EOF'
"\e[A": history-search-backward
"\e[B": history-search-forward
set show-all-if-ambiguous on
set completion-ignore-case on
EOF

# zero the free disk space -- for better compression of the box file.
dd if=/dev/zero of=/EMPTY bs=1M || true && sync && rm -f /EMPTY && sync
