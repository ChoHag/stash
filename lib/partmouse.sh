#!/bin/sh

# Disable partman
chmod -x /lib/partman/*.d/*

# For now this hack so I can move on
for x in       \
  o            \
  n p 1 '' +1g \
  t 82         \
  n p 2 '' ''  \
  a 2          \
  w; do
  echo $x
done | fdisk /dev/vda
mkswap /dev/vda1
swapon /dev/vda1
modprobe ext4
mkfs.ext4 /dev/vda2
mkdir -p /target
mount /dev/vda2 /target
mkdir -p /target/etc
echo '/dev/vda1 none swap sw 0 0' >> /target/etc/fstab
echo '/dev/vda2 / ext4 defaults,noatime,nodiratime,errors=remount-ro 1 1' >> /target/etc/fstab
echo '/dev/sr0 /media/cdrom defaults,noauto,iso9660 ro 0 0' >> /target/etc/fstab # needed by d-i
exit 0

# Later, something more or less like this
all=$(list_devices)
cnt=0

while [ $cnt -lt $expected ]; do
  opts=$part_${cnt}__opt
  parts=$part_${cnt}__count

  case $devtype in
  block)
    fdisk=o\\n               # wipe
    for _id in `seq 0 $parts`; do
      #if dos; then
        case $_id in
        0)     part=$(($_id+1)) t=p\\n1\\n     q= ;;
        [012]) part=$(($_id+1)) t=p\\n$part\\n q=$part\\n;;
        3)     part=$(($_id+2)) t=e\\n         q=$part\\n;;
        *)     part=$(($_id+2)) t=             q=$part\\n;;
        esac
      #elif gpt; then
      #  case $_id in
      #  0) part=$(($_id+1)) t= q= ;;
      #  *) part=$(($_id+1)) t= q=$part\\n ;;
      #  esac
      #fi
      fdisk=$fdisk'n\n'      # new
      fdisk=$fdisk$t         # primary/extended
      fdisk=$fdisk'\n'       # start
      fdisk=$fdisk+$size'\n' # end
      case $fstype in
      lvm)   fdisk=$fdisk\t\\n${q}8e\\n;;
      raid)  fdisk=$fdisk\t\\n${q}fd\\n;;
      swap)  fdisk=$fdisk\t\\n${q}82\\n;;
      zfs)   fdisk=$fdisk\t\\n${q}da\\n;; # Non-FS data; that or 88=plaintext
      crypt) fdisk=$fdisk\t\\n${q}da\\n;;
      ext*) ;;
      *) echo Unknown fstype $fstype >&2; exit 1;;
      esac
      if [ -n "$part_${cnt}_${_id}_bootable" ]; then
        fdisk=$fdisk\a\\n$part\\n
      fi
    done
    printf "$fdisk"w\\n | fdisk $dev

    for part in `seq 0 $parts`; do
      case $part in [012]) dev=$(($part+1));; *) dev=$(($part+2));; esac
      dev=/dev/XXX$dev
      case $fstype in
      lvm)   pvcreate $dev;;
      raid)  :;;
      swap)  mkswap $dev; attach_target;;
      zfs)   :;;
      crypt) :;;
      ext*)  mkfs.$fstype $dev; attach_target;;
      esac
    done
    ;;

  crypt)
    ...
    ;;

  lvm)
    vgcreate $opt $vgname $devs
    for _id in `seq 0 $parts`; do
      lvcreate $opt --name $lvname $vgname
      attach_target
    done
    ;;

  raid)
    mdadm -C /dev/md* -n ? -l ? $devs
    # can be formatted as-is or partitioned further; refactor (block).
    ;;

  zfs)
    zpool create $name $devs $opts
    for part; do
      zfs create ...
    done
    ;;
  esac

done

sort </tmp/tomount | while read mp dev; do
  mount $dev /target$mp
done

mkdir -p /target/etc
cp /tmp/newfstab /target/etc/fstab
