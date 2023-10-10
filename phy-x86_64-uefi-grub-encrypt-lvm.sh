#!/bin/sh -eu
# shellcheck disable=SC2039

#############################################################################
# Generated on Tue 10 Oct 2023 15:06:17 BST by create-alpine-disk-image
# version 0.3-DEV using the following options:
#
#   --bootloader grub
#   --boottype uefi
#   --cpu-vendor intel
#   --disable-optimisation
#   --encryption-type luks
#   --ethernet-module r8169
#   --image-filename phy-x86_64-uefi-grub-encrypt-lvm.img
#   --keymap "gb gb-extd"
#   --locale en_GB
#   --luks-passphrase test123
#   --lvm
#   --physical pc
#   --script-filename output/phy-x86_64-uefi-grub-encrypt-lvm.sh
#   --script-host-os alpine
#   --use-ramdisk
#
#############################################################################

if [ "$(id -u)" -ne 0 ]; then
  printf '\nThis script must be run as the root user!\n\n'
  exit 1
fi


#############################################################################
##   Functions
#############################################################################

#
# Checks that the host OS has all necessary packages installed.
#
check_for_required_packages() {
  local _required_packages
  local _host_os_major_version
  local _host_os

  _host_os=$(detect_host_os)
  case $_host_os in
    alpine )
      _host_os_major_version="$(grep VERSION_ID /etc/os-release | sed -E -e 's/^VERSION_ID=([0-9]+\.[0-9]+).*/\1/g')"
      _required_packages="blkid busybox coreutils jq lsblk qemu-img tar wget dosfstools parted e2fsprogs cryptsetup lvm2"

      case $_host_os_major_version in
        3.13 | 3.14 )
          # Select:
          #    util-linux for: losetup, mount, umount
          #    (Busybox versions are not suitable)
          _required_packages="$_required_packages util-linux"
          ;;
        3.15 )
          # Select:
          #    util-linux-misc for: losetup, mount, umount
          #    (Busybox versions are not suitable)
          _required_packages="$_required_packages util-linux-misc"
          ;;
        3.16 )
          # Select:
          #    losetup & util-linux-misc for: losetup, mount, umount
          #    (Busybox versions are not suitable)
          _required_packages="$_required_packages losetup util-linux-misc"
          ;;
        * )
          # Select:
          #    losetup, mount, & umount for: losetup, mount, umount
          #    (Busybox versions are not suitable)
          _required_packages="$_required_packages losetup mount umount"
          ;;
      esac
      # shellcheck disable=SC2086
      if ! apk info -e -q $_required_packages; then
        printf '\nThe following Alpine packages need to be installed:\n\n'
        printf '  %s\n\n' "$_required_packages"
        exit 1
      fi
      ;;

    * )
      case $_host_os in
        alpine | debian | ubuntu )
          printf \
            '\nRe-run create-alpine-disk-image specifying '\''--script-host-os %s'\''!\n\n' \
            "$_host_os"
          ;;
        * )
          printf '\nUnsupported host OS!\n\n' ;;
      esac
      exit 1
      ;;
  esac
}

#
# Check that the host OS has necessary packages installed for
# running user-mode QEMU via binfmt and that it is configured.
#
check_binfmt_packages() {
  local _alpine_arch_package="qemu-x86_64"
  local _arch="x86_64"
  local _binfmt_file="/proc/sys/fs/binfmt_misc/qemu-x86_64"

  local _binfmt_arch_enabled _host_arch _host_os _required_packages

  _host_arch=$(detect_host_arch)

  if [ "$_host_arch" != "$_arch" ]; then
    _host_os=$(detect_host_os)
    case $_host_os in
      alpine )
        _required_packages="qemu-openrc $_alpine_arch_package"
        # shellcheck disable=SC2086
        if ! apk info -e -q $_required_packages; then
          printf '\nThe following Alpine packages need to be installed:\n\n'
          printf '  %s\n\n' "$_required_packages"
          exit 1
        fi
        ;;

      * )
        case $_host_os in
          alpine | debian | ubuntu )
            printf \
              '\nRe-run create-alpine-disk-image specifying '\''--script-host-os %s'\''!\n\n' \
              "$_host_os"
            ;;
          * )
            printf '\nUnsupported host OS!\n\n' ;;
        esac
        exit 1
        ;;
    esac

    # Is binfmt configured for this QEMU arch?
    if [ -e "$_binfmt_file" ]; then
      _binfmt_arch_enabled=$(head -1 ${_binfmt_file})
      if [ "$_binfmt_arch_enabled" = "enabled" ]; then
        return
      else
        printf '\nBinfmt is not enabled for %s\n\n' "$_arch"
        exit 1
      fi
    else
      printf '\nBinfmt and QEMU are not configured for %s\n\n' "$_arch"
      exit 1
    fi
  fi
}

#
# Determine the host architecture that script is being run on.
#
detect_host_arch() {
  uname -m
}

#
# Determine the Linux distro that script is being run on.
#
detect_host_os() {
  grep "^ID=" /etc/os-release | sed -e 's/^ID=//'
}

#
# Unmount filesystems whenever an error occurs in the script.
#
# shellcheck disable=SC2317
error_cleanup() {
  write_log
  write_log
  write_log "AN ERROR OCCURRED, cleaning up before aborting!"
  write_log
  write_log

  if [ -f "$chroot_dir"/chroot.log ]; then
    cat "$chroot_dir"/chroot.log >> "$logfile"
  fi

  normal_cleanup "error"

  rm -f crypto_keyfile.bin

  rm "$image_full_filename"
  sync -f "$ramdisk_dir"
  unmount_ramdisk
}

#
# Get the UUID of the filesystem in the specified device.
#
get_uuid_from_device() {
  blkid -s UUID -o value "$1"
}

#
# Unmount filesystems mounted inside chroot directory.
#
normal_cleanup() {
  local _param="${1:-}"

  # Clear exit trap function
  trap EXIT

  if [ -z "$_param" ]; then
    write_log "Normal cleanup"
  fi

  unmount_chroot_fs "/tmp"
  if [ -n "$working_dir" ]; then
    rmdir "$working_dir"
  fi
  unmount_chroot_fs "/dev"
  unmount_chroot_fs "/sys"
  unmount_chroot_fs "/proc"
  unmount_chroot_fs "/boot/efi"
  unmount_chroot_fs "/boot"
  unmount_chroot_fs "/cidata"
  unmount_chroot_fs "/"

  vgchange -an >> "$logfile"

  cryptsetup close lukspart >> "$logfile"

  if [ -n "$loop_device" ]; then
    write_log "Freeing up loop device '$loop_device'" 2
    losetup -d "$loop_device" >> "$logfile"
    _rc=$?
    if [ $_rc -ne 0 ]; then
      printf '\nThere was a problem freeing the loop device '\''%s'\''!\n\n' \
        "$loop_device"
      exit 1
    fi
  fi
}

#
# Unmount a filesystem inside chroot.
#
unmount_chroot_fs() {
  local _mountpoint="$1"
  local _where_from="${2:-inside chroot}"

  local _full_path _pseudo_path

  if [ "$_mountpoint" = "/" ]; then
    _full_path="$chroot_dir"
    _pseudo_path="root filesystem"
  else
    _full_path="${chroot_dir}${_mountpoint}"
    _pseudo_path="$_mountpoint"
  fi

  if mount | grep -q "$_full_path" ; then
    write_log "Unmounting ${_pseudo_path} ${_where_from}" 2
    umount -l -f "$_full_path" >> "$logfile"
  fi
}

#
# Unmount ramdisk.
#
unmount_ramdisk() {
  local _rc

  # Give any previous operations using the ramdisk time to complete
  sleep 10

  if mount | grep -q "$ramdisk_dir" ; then
    _rc=1
    while [ $_rc -ne 0 ]; do
      write_log "Unmounting ramdisk"
      umount "$ramdisk_dir" >> "$logfile"
      _rc=$?
      sleep 5
    done
    sleep 5

    write_log "Deleting ramdisk directory"
    rmdir "$ramdisk_dir" >> "$logfile"
  fi
}

#
# Write debug messages only to the log file.
#
write_debug_log() {
  local _log_entry="$1"
  local _indent="${2:-0}"

  local _current_time

  # Debug not enabled so do nothing
  true
}

#
# Write log messages to both logfile (with timestamp) and stdout.
#
write_log() {
  local _log_entry="${1:-}"
  local _indent="${2:-0}"

  local _current_time

  _current_time=$(printf "[%s]" "$(date -u "+%Y-%m-%d %H:%M:%S")")
  # shellcheck disable=SC1117
  printf "${_current_time} %${_indent}s${_log_entry}\n" >> "$logfile"
  # shellcheck disable=SC1117
  printf "%${_indent}s$_log_entry\n"
}

#############################################################################
##   Main Section
#############################################################################

chroot_dir="./chroot"
images_dir="./alpine-images"
TMPDIR="/var/tmp"

image_filename="phy-x86_64-uefi-grub-encrypt-lvm.img"
logfile="phy-x86_64-uefi-grub-encrypt-lvm.log"

luks_passphrase="test123"

# Create empty logfile
:> $logfile

ramdisk_dir="./ramdisk"
image_full_filename="$ramdisk_dir/$image_filename"
working_dir=""


check_for_required_packages
check_binfmt_packages

# Ensure if any errors occur that various cleanup operations happen
trap error_cleanup EXIT

mkdir -p $images_dir

write_log "Setting up ramdisk"
mkdir -p $ramdisk_dir
mount -t tmpfs -o size=3G tmpfs $ramdisk_dir >> $logfile

write_log "Creating sparse disk image of 638MiB"
truncate -s 638M $image_full_filename >> $logfile

write_log "Partitioning disk image for UEFI"
{
  write_debug_log "Creating gpt disk label" 2
  parted --machine --script --align=optimal $image_full_filename \
    mklabel gpt >> "$logfile" 2>&1
  write_debug_log "Creating 16MiB ESP partition" 2
  parted --machine --script --align=optimal $image_full_filename \
    unit MiB mkpart primary fat16 1MiB 17MiB >> "$logfile" 2>&1
  write_debug_log "Setting partition esp flag on" 2
  parted --machine --script --align=optimal $image_full_filename \
    set 1 esp on >> "$logfile" 2>&1
  write_debug_log "Labelling GPT partition 1 as 'ESP'" 2
  parted --machine --script $image_full_filename \
    name 1 "ESP" >> "$logfile" 2>&1
  write_debug_log "Creating 1MiB cidata partition" 2
  parted --machine --script --align=optimal $image_full_filename \
    unit MiB mkpart primary  17MiB 18MiB >> "$logfile" 2>&1
  write_debug_log "Labelling GPT partition 2 as 'cidata'" 2
  parted --machine --script $image_full_filename \
    name 2 "cidata" >> "$logfile" 2>&1
  write_debug_log "Creating 620MiB LUKS partition" 2
  parted --machine --script --align=optimal $image_full_filename \
    unit MiB mkpart primary  18MiB 100% >> "$logfile" 2>&1
  write_debug_log "Labelling GPT partition 3 as 'LUKS'" 2
  parted --machine --script $image_full_filename \
    name 3 "LUKS" >> "$logfile" 2>&1
}

write_log "Setting up loop device for disk image"
{
  write_log "Ensuring that loop driver is loaded (if necessary)" 2
  if [ ! -c /dev/loop-control ]; then
    loop_module_filename=$(modinfo -F filename loop 2>/dev/null)
    if [ "$loop_module_filename" != "" ] && \
       [ "$loop_module_filename" != "(builtin)" ]; then
      modprobe loop 2>> $logfile
    else
      printf '\nThere is a problem with loop devices!\n\n'
      exit 1
    fi
  fi
  
  write_log "Setting up loop device with 512-byte sector size for disk image" 2
  loop_device=$(losetup -P --show -b 512 -f $image_full_filename 2>> $logfile)
  _rc=$?
  if [ $_rc -ne 0 ]; then
    if [ -n "$loop_device" ]; then
      unset loop_device
      printf '\nThere was a problem creating the loop device!\n\n'
    else
      printf \
        '\nThere was a problem creating the loop device '\''%s'\''!\n\n' \
        "$loop_device"
    fi
    exit 1
  fi
  if [ -z "$loop_device" ]; then
    printf '\nThere was a problem creating the loop device. Aborting!\n\n'
    exit 1
  fi
}

write_log "Setting up LUKS v1 device using aes-xts-plain64 cipher"
{
  luks_device="${loop_device}p3"
  write_log "Formatting partition as LUKS version 1" 2
  echo "$luks_passphrase" | cryptsetup -q --verbose luksFormat \
    --pbkdf pbkdf2 --type luks1 --use-random \
    --cipher aes-xts-plain64 --hash sha256 --key-size 512 \
    "$luks_device" >> "$logfile" 2>&1

  write_log "Creating keyfile for LUKS" 2
  dd bs=512 count=4 if=/dev/random of=crypto_keyfile.bin iflag=fullblock \
    >> "$logfile" 2>&1

  write_log "Adding keyfile to LUKS device" 2
  echo "$luks_passphrase" | \
    cryptsetup luksAddKey --pbkdf pbkdf2 "$luks_device" ./crypto_keyfile.bin >> "$logfile"

  write_log "Opening LUKS device" 2
  cryptsetup open --type luks1 --key-file ./crypto_keyfile.bin \
    "$luks_device" lukspart
  luks_part_uuid=$(get_uuid_from_device "$luks_device")
}

write_log "Setting up LVM device"
{
  lvm_device="/dev/mapper/lukspart"

  write_log "Creating LVM physical volume" 2
  pvcreate --verbose "$lvm_device" >> "$logfile" 2>&1
  _pv_size=$(pvdisplay --verbose 2>&1 | grep "PV Size" | sed -e 's/^.*PV Size[ ]*//' -e 's/\.[0-9]* MiB.*$//')
  write_debug_log "    Resultant PV size ${_pv_size}MiB"

  write_log "Creating LVM volume group" 2
  vgcreate --verbose vg0 "$lvm_device" >> "$logfile" 2>&1

  write_log "Creating 504MiB LVM logical volume for rootfs" 2
  lvcreate --verbose -L 504m vg0 -n root >> "$logfile" 2>&1

  write_log "Creating 68MiB LVM logical volume for boot" 2
  lvcreate --verbose -L 68m vg0 -n boot >> "$logfile" 2>&1

  write_log "Creating 20MiB LVM logical volume for logs" 2
  lvcreate --verbose -L 20m vg0 -n logs >> "$logfile" 2>&1
}

write_log "Formatting and mounting filesystems"
{
  uefi_part_device="${loop_device}p1"
  write_log \
    "Formatting FAT16 filesystem with 512-byte sectors on ESP partition" 2
  mkfs.fat -F16 -s 1 -S 512 -n "SYSTEM EFI" "$uefi_part_device" \
    >> "$logfile" 2>&1

  esp_fs_uuid="$(get_uuid_from_device "$uefi_part_device")"

  cidata_part_device="${loop_device}p2"

  write_log \
    "Formatting FAT12 CIDATA filesystem with 512-byte sectors on partition" 2
  mkfs.fat -F12 -s 1 -S 512 -n CIDATA "$cidata_part_device" \
    >> "$logfile" 2>&1

  root_part_device="/dev/mapper/vg0-root"
  logs_part_device="/dev/mapper/vg0-logs"
  boot_part_device="/dev/mapper/vg0-boot"

  write_log "Formatting Ext4 root filesystem on LVM-on-LUKS device" 2
  mkfs.ext4 -L alpine-root -I 256 -q "$root_part_device" >> "$logfile" 2>&1


  write_log "Formatting Ext4 boot filesystem on LVM-on-LUKS device" 2
  mkfs.ext4 -L boot -I 256 -q "$boot_part_device" >> "$logfile" 2>&1


  write_log "Formatting Ext4 logs filesystem on LVM-on-LUKS device" 2
  mkfs.ext4 -L logs -I 256 -q "$logs_part_device" >> "$logfile" 2>&1


  write_log "Mounting root filesystem onto $chroot_dir" 2
  mkdir -p "$chroot_dir"
  mount -o private "$root_part_device" "$chroot_dir" >> "$logfile" 2>&1

  write_log "Mounting boot filesystem onto $chroot_dir/boot" 2
  mkdir -p "$chroot_dir"/boot
  mount -o private "$boot_part_device" "$chroot_dir"/boot >> "$logfile" 2>&1

  write_log "Mounting ESP filesystem onto $chroot_dir/boot/efi" 2
  mkdir -p "$chroot_dir"/boot/efi
  mount -o private "$uefi_part_device" "$chroot_dir"/boot/efi \
    >> "$logfile" 2>&1

  write_log "Mounting logs filesystem onto $chroot_dir/var/logs" 2
  mkdir -p "$chroot_dir"/var/log
  mount -o private "$logs_part_device" "$chroot_dir"/var/log >> "$logfile" 2>&1

  write_log "Mounting cloud-init YAML filesystem onto $chroot_dir/cidata" 2
  mkdir -p "$chroot_dir"/cidata
  mount -o private "$cidata_part_device" "$chroot_dir"/cidata >> "$logfile"
}

write_log "Moving LUKS keyfile into chroot directory" 2
{
  mv crypto_keyfile.bin "$chroot_dir"/
  chmod 400 "$chroot_dir"/crypto_keyfile.bin
}

write_log "Copying system's /etc/resolv.conf into chroot filesystem"
mkdir -p "$chroot_dir"/etc
cp /etc/resolv.conf "$chroot_dir"/etc/

write_log "Creating /etc/apk/repositories file inside chroot"
mkdir -p "$chroot_dir"/etc/apk/keys
{
  printf '%s/%s/main\n' "https://dl-cdn.alpinelinux.org/alpine" "edge"
  printf '%s/%s/community\n' "https://dl-cdn.alpinelinux.org/alpine" "edge"
  printf '%s/%s/testing\n' "https://dl-cdn.alpinelinux.org/alpine" "edge"
} > "$chroot_dir"/etc/apk/repositories

write_log "Bootloader packages to be installed are: grub grub-efi"

write_log \
  "Install base Alpine & bootloader packages for x86_64 arch inside chroot"
{
  _apk_binary="apk"

  # shellcheck disable=SC2086
  $_apk_binary --arch "x86_64" --initdb --allow-untrusted \
    --root $chroot_dir --update-cache \
    add alpine-base efivar dosfstools ifupdown-ng mkinitfs grub grub-efi \
    >> "$logfile" 2>&1
  _rc=$?
  if [ $_rc -ne 0 ]; then
    write_log "Failure while installing base Alpine, error code: $_rc"
    exit 1
  fi
}

write_log "Mounting tmp, /proc, /sys, and /dev special filesystems in chroot"
{
  working_dir=$(mktemp -d -p /tmp create-alpine.XXXXXX)
  _rc=$?
  if [ $_rc -ne 0 ]; then
    printf '\nThere was a problem creating a temporary working directory!\n\n'
    exit 1
  fi
  mount -v -t none -o rbind "$working_dir" $chroot_dir/tmp
  mount -v --make-rprivate $chroot_dir/tmp
  mount -v -t proc none $chroot_dir/proc
  mount -v -t none -o rbind /sys $chroot_dir/sys
  mount -v --make-rprivate $chroot_dir/sys
  mount -v -t none -o rbind /dev $chroot_dir/dev
  mount -v --make-rprivate $chroot_dir/dev
} >> $logfile 2>&1

#############################################################################
##		Start of Chroot section
#############################################################################

cat <<EOT | chroot $chroot_dir /bin/sh -eu
#!/bin/sh -eu

keymap="gb gb-extd"
locale="en_GB.UTF-8"
umask="077"
timezone="America/New_York"

############################################################################
##		Chroot Functions
############################################################################

add_fstab_entry() {
  local _entry_type="\$1"
  local _entry_value="\$2"
  local _mount_point="\$3"
  local _fs_type="\$4"
  local _fs_options="\${5:-}"
  local _entry_log="\${6:-}"

  local _fstab_entry

  if [ "\$_entry_type" = "BIND" ]; then
    _fs_options="bind,\${_fs_options}"
    local _fs_passno="0"
  elif [ "\$_fs_type" = "swap" ]; then
    _mount_point="none"
    _fs_options="sw"
    local _fs_passno="0"
    _entry_log="Swap partition"
  elif [ "\$_fs_type" = "tmpfs" ]; then
    local _fs_passno="0"
  elif [ "\$_mount_point" = "/" ]; then
    local _fs_passno="1"
  else
    local _fs_passno="2"
  fi

  if [ "\$_entry_type" = "BIND" ] || [ "\$_entry_type" = "DEVICE" ]; then
    _fstab_entry="\${_entry_value}"
  else
    _fstab_entry="\${_entry_type}=\${_entry_value}"
  fi
  _fstab_entry="\${_fstab_entry}\t\${_mount_point}\t\${_fs_type}\t\${_fs_options} 0 \${_fs_passno}"

  write_log "Add \${_entry_log} entry" 2
  # shellcheck disable=SC2059
  printf "\${_fstab_entry}\n" >> /etc/fstab
}

all_entries_in_comma_list_except() {
  local _cfaeicle_comma_list="\$1"
  local _cfaeicle_cl_except="\$2"

  all_entries_in_list_except "\$_cfaeicle_comma_list" \\
    "\$_cfaeicle_cl_except" ","
}

all_entries_in_list_except() {
  local _cfaeile_list="\$1"
  local _cfaeile_keep_item="\$2"
  local _cfaeile_separator="\$3"

  local _cfaeile_check _cfaeile_check_item _cfaeile_resulting_list=""

  _cfaeile_check="\$_cfaeile_list"
  while true; do
    _cfaeile_check_item="\$(first_entry_in_list "\$_cfaeile_check" "\$_cfaeile_separator")"
    case \$_cfaeile_check_item in
      generic )
        : ;;
      * )
        if [ "\$_cfaeile_check_item" != "\$_cfaeile_keep_item" ]; then
          if [ -n "\$_cfaeile_resulting_list" ]; then
            _cfaeile_resulting_list="\${_cfaeile_resulting_list}\${_cfaeile_separator}\${_cfaeile_check_item}"
          else
            _cfaeile_resulting_list="\${_cfaeile_check_item}"
          fi
        fi
        ;;
    esac
    if [ "\${_cfaeile_check%\$_cfaeile_separator*}" = "\$_cfaeile_check" ]; then
      # No more entries
      break
    else
      _cfaeile_check="\${_cfaeile_check#\$_cfaeile_check_item\$_cfaeile_separator}"
    fi
  done

  echo "\$_cfaeile_resulting_list"
}

check_list_of_modules_exist() {
  local _cfclome_modules_list="\$1"

  local _cfclome_filename _cfclome_search_list _cfclome_search_list_item
  local _cfclome_resultant_list

  _cfclome_search_list="\$_cfclome_modules_list"
  _cfclome_resultant_list="\$_cfclome_modules_list"
  while true; do
    _cfclome_search_list_item="\$(first_entry_in_comma_list "\$_cfclome_search_list")"

    _cfclome_filename="\$(modinfo -k \$(get_kernel_version) -F filename "\$_cfclome_search_list_item" 2>/dev/null)"
    if [ -z "\$_cfclome_filename" ] || \\
       [ "\$_cfclome_filename" = "(builtin)" ]; then
      # Remove this module name from the resultant list
      _cfclome_resultant_list="\$(all_entries_in_comma_list_except "\$_cfclome_resultant_list" "\$_cfclome_search_list_item")"
    fi

    if [ "\${_cfclome_search_list%,*}" = "\$_cfclome_search_list" ]; then
      # No more entries
      break
    else
      _cfclome_search_list="\${_cfclome_search_list#"\$_cfclome_search_list_item",}"
    fi
  done

  echo "\$_cfclome_resultant_list"
}

define_cmdline_for_luks_encryption() {
  echo "cryptroot=UUID=${luks_part_uuid} cryptdm=lukspart"
}

echo_lines_from_comma_list() {
  local _cfelfcl_output_formatting="\$1"
  local _cfelfcl_input_cl_list="\$2"

  local _cfelfcl_cl_list _cfelfcl_cl_list_item

  _cfelfcl_cl_list="\$_cfelfcl_input_cl_list"
  while true; do
    _cfelfcl_cl_list_item="\$(first_entry_in_comma_list "\$_cfelfcl_cl_list")"
    printf "\$_cfelfcl_output_formatting\n" "\$_cfelfcl_cl_list_item"
    if [ "\${_cfelfcl_cl_list%,*}" = "\$_cfelfcl_cl_list" ]; then
      # No more entries
      break
    else
      _cfelfcl_cl_list="\${_cfelfcl_cl_list#\$_cfelfcl_cl_list_item,}"
    fi
  done
}

find_module_full_path() {
  local _module="\$1"

  local _module_path

  _module_path="\$(find /lib/modules/ -name "\$_module.ko*" | \\
    sed -e 's/^.*kernel/kernel/' -e 's/\.ko.*$//')"

  if [ -z "\$_module_path" ]; then
    _module="\$(echo "\$_module" | sed -e 's/-/_/g')"
    _module_path="\$(find /lib/modules/ -name "\$_module.ko*" | \\
      sed -e 's/^.*kernel/kernel/' -e 's/\.ko.*$//')"
  fi

  if [ -n "\$_module_path" ]; then
    _module_path="\${_module_path}.ko*"
  fi

  echo "\$_module_path"
}

first_entry_in_comma_list() {
  local _cffeicl_comma_list="\$1"

  first_entry_in_list "\$_cffeicl_comma_list" ","
}

first_entry_in_list() {
  local _cffeil_list="\$1"
  local _cffeil_separator="\$2"

  echo "\${_cffeil_list%%"\$_cffeil_separator"*}"
}

get_kernel_package_version() {
  apk info linux-lts | head -n 1 | sed -e "s/^linux-lts-//" \\
    -e 's/ .*//'
}

get_kernel_version() {
  apk info linux-lts | head -n 1 | sed -e "s/^linux-lts-//" \\
    -e 's/-r/-/' -e 's/ .*//' -Ee "s/^(.*)$/\1-lts/"
}

write_debug_log() {
  local _log_entry="\$1"
  local _indent=\${2:-0}

  local _current_time

  # Debug not enabled so do nothing
  true
}

write_log() {
  local _log_entry="\$1"
  local _indent=\${2:-0}

  local _current_time

  _current_time=\$(printf "[%s]" "\$(date -u "+%Y-%m-%d %H:%M:%S")")
  # shellcheck disable=SC1117
  printf "\$_current_time chroot: %\${_indent}s\${_log_entry}\n" >> /chroot.log
  # shellcheck disable=SC1117
  printf "chroot: %\${_indent}s\${_log_entry}\n"
}

############################################################################
##		Chroot Main Section
############################################################################

write_log "Add /etc/fstab entries"
{
  add_fstab_entry DEVICE "tmpfs" "/tmp" "tmpfs" "nosuid,nodev" "/tmp on tmpfs"
  add_fstab_entry DEVICE "/dev/mapper/vg0-root" "/" "ext4" \\
    "rw,relatime" "rootfs"
  add_fstab_entry UUID "$esp_fs_uuid" "/boot/efi" "vfat" "rw" "ESP filesystem"
  add_fstab_entry DEVICE "/dev/mapper/vg0-boot" "/boot" "ext4" "rw,relatime" "boot"
  add_fstab_entry DEVICE "/dev/mapper/vg0-logs" "/var/log" "ext4" "rw,relatime" "logsfs"
}

write_log "Adding additional repos"
{
  write_log "Adding community repo to /etc/apk/repositories" 2
  cat <<-_SCRIPT_ >> /etc/apk/repositories
	https://dl-cdn.alpinelinux.org/alpine/edge/community
	_SCRIPT_
  write_log "Adding testing repo to /etc/apk/repositories" 2
  cat <<-_SCRIPT_ >> /etc/apk/repositories
	https://dl-cdn.alpinelinux.org/alpine/edge/testing
	_SCRIPT_
}

write_log "Updating packages info"
{
  write_log "Updating packages list" 2
  apk update >> /chroot.log

  write_log "Upgrading base packages if necessary" 2
  apk -a upgrade >> /chroot.log
}

write_log "Doing basic OS configuration"
{
  write_log "Setting the login and MOTD messages" 2
  printf '\nWelcome\n\n' > /etc/issue
  printf '\n\n%s\n\n' "Alpine x86_64 PC server" > /etc/motd

  write_log "Setting the keymap to '\$keymap'" 2
  # shellcheck disable=SC2086
  setup-keymap \$keymap >> "/chroot.log" 2>&1

  locale_file="50-cloud-init-locale.sh"
  if [ -e "\$locale_file" ]; then
    write_log "Setting locale to \$locale" 2
    sed -i -E -e "s/^(export LANG=)C.UTF-8/\1\$locale/" \\
      /etc/profile.d/\${locale_file}
  else
    write_log "Creating profile file to set locale to \$locale" 2
    {
      printf '# Created by create-alpine-disk-image\n#\n'
      printf 'export LANG=%s\n' "\$locale"
    } > /etc/profile.d/\${locale_file}
  fi

  write_log "Setting system-wide UMASK" 2
  {
    umask_file="05-umask.sh"
    write_log "Creating profile file to set umask to \$umask" 4
    {
      printf '# Created by create-alpine-disk-image\n\n'
      printf 'umask %s\n' "\$umask"
    } > /etc/profile.d/\${umask_file}
  }

  write_log "Set OpenRC to log init.d start/stop sequences" 2
  sed -i -e 's|[#]rc_logger=.*|rc_logger="YES"|g' /etc/rc.conf

  write_log \\
    "Configure /etc/init.d/bootmisc to keep previous dmesg logfile" 2
  sed -i -e 's|[#]previous_dmesg=.*|previous_dmesg=yes|g' /etc/conf.d/bootmisc

  write_log "Enable colour shell prompt" 2
  cp /etc/profile.d/color_prompt.sh.disabled /etc/profile.d/color_prompt.sh

  write_log "Enable mdev init.d services" 2
  setup-devd mdev >> /chroot.log 2>&1 || true

  rmdir /media/floppy
}

write_log "Enable init.d scripts"
{
  rc-update add devfs sysinit
  rc-update add dmesg sysinit

  rc-update add bootmisc boot
  rc-update add hostname boot
  rc-update add modules boot
  rc-update add swap boot
  rc-update add seedrng boot
  rc-update add osclock boot

  rc-update add networking default

  rc-update add killprocs shutdown
  rc-update add mount-ro shutdown
  rc-update add savecache shutdown
} >> /chroot.log 2>&1

add_packages="doas cpio ca-certificates htop kbd-bkeymaps logrotate musl-locales sshguard hwinfo acct util-linux-login shadow cryptsetup lvm2 device-mapper iptables e2fsprogs-extra dhcpcd chrony openssh-server rsyslog"
write_log "Install additional packages: \$add_packages"
{
  # shellcheck disable=SC2086
  apk add \$add_packages >> /chroot.log 2>&1
}

add_os_cfg_pkgs="cloud-init lsblk parted sfdisk sgdisk ssh-import-id busybox"
write_log "Install OS configuration packages: \$add_os_cfg_pkgs"
{
  # shellcheck disable=SC2086
  apk add \$add_os_cfg_pkgs >> /chroot.log 2>&1
}

machine_specific_pkgs="cpufrequtils ethtool irqbalance lm-sensors smartmontools hd-idle hdparm acpid fwupd cpufrequtils ethtool irqbalance"
write_log \\
  "Install additional machine specific packages: \$machine_specific_pkgs"
{
  # shellcheck disable=SC2086
  apk add \$machine_specific_pkgs >> /chroot.log 2>&1
}

write_log "Doing additional OS configuration"
{
  write_log "Configure doas" 2
  {
    write_log "Adding doas configuration for root user" 4
    cat <<-_SCRIPT_ >> /etc/doas.conf
	
	# Allow root to run doas (i.e. "doas -u <user> <command>")
	permit nopass root
	_SCRIPT_

    write_log "Enabling doas configuration for wheel group" 4
    sed -i -E -e 's/^[#][ ]*(permit persist :wheel)$/\1/g' \\
      /etc/doas.conf
  }
}

write_log "Configuring cloud-init"
{
  write_log "Running setup-cloud-init" 2
  setup-cloud-init >> /chroot.log 2>&1 || true

  write_log "Setting DataSources list with: NoCloud" 2
  cat <<-_SCRIPT_ > /etc/cloud/cloud.cfg.d/01-datasources.cfg
	# /etc/cloud/cloud.cfg.d/01-datasources.cfg
	
	datasource_list: ['NoCloud']
	_SCRIPT_

  write_log "Setting up modules info" 2
  cat <<-_SCRIPT_ > /etc/cloud/cloud.cfg.d/01-modules.cfg
	# /etc/cloud/cloud.cfg.d/01-modules.cfg
	
	# Modules that run in 'init' stage
	cloud_init_modules:
	  - bootcmd
	  - write_files
	  - growpart
	  - resizefs
	  - disk_setup
	  - mounts
	  - set_hostname
	  - update_hostname
	  - update_etc_hosts
	  - resolv_conf
	  - ca_certs
	  - rsyslog
	  - users_groups
	  - ssh
	
	# Modules that run in 'config' stage
	cloud_config_modules:
	  - ssh_import_id
	  - keyboard
	  - locale
	  - set_passwords
	  - apk_configure
	  - ntp
	  - timezone
	  - runcmd
	
	# Modules that run in 'final' stage
	cloud_final_modules:
	  - package_update_upgrade_install
	  - write_files_deferred
	  - ansible
	  - scripts_vendor
	  - scripts_per_once
	  - scripts_per_boot
	  - scripts_per_instance
	  - scripts_user
	  - ssh_authkey_fingerprints
	  - keys_to_console
	  - phone_home
	  - final_message
	  - power_state_change
	_SCRIPT_

  write_log "Setting up System info" 2
  cat <<-_SCRIPT_ > /etc/cloud/cloud.cfg.d/01-system-info.cfg
	# /etc/cloud/cloud.cfg.d/01-system-info.cfg
	
	system_info:
	  distro: alpine
	  default_user:
	_SCRIPT_

  write_log "Setting the default username to 'alpine'" 4
  cat <<-_SCRIPT_ >> /etc/cloud/cloud.cfg.d/01-system-info.cfg
	    name: alpine
	    doas:
	      - permit nopass alpine
	_SCRIPT_

  write_log \\
    "Do not lock password of default user account (workaround)" 4
  write_log \\
    "Set password of default user account to invalid value (workaround)" 4
  cat <<-_SCRIPT_ >> /etc/cloud/cloud.cfg.d/01-system-info.cfg
	    lock_passwd: false
	    # Cannot lock password so instead set to invalid value.
	    passwd: "*"
	    gecos: Default cloud-init user
	    groups: [adm, wheel]
	    shell: /bin/ash
	  paths:
	    cloud_dir: /var/lib/cloud/
	    templates_dir: /etc/cloud/templates/
	  ssh_svcname: sshd
	_SCRIPT_

  write_log "Disabling growpart and resize_rootfs" 2
  cat <<-_SCRIPT_ > /etc/cloud/cloud.cfg.d/02-disable-grow-and-resize-fs.cfg
	# /etc/cloud/cloud.cfg.d/02-disable-grow-and-resize-fs.cfg
	
	# Disable growpart
	growpart:
	  mode: off
	
	# Disable resize_rootfs
	resize_rootfs: false
	_SCRIPT_

  write_log "Setting up SSH info" 2
  cat <<-_SCRIPT_ > /etc/cloud/cloud.cfg.d/02-ssh.cfg
	# /etc/cloud/cloud.cfg.d/02-ssh.cfg
	
	# Prevent SSH access to root user
	disable_root: true
	
	# Delete any pre-existing SSH hosts keys
	ssh_deletekeys: true
	
	# Only create ED25519 SSH host key
	ssh_genkeytypes: ["ed25519"]
	
	# Disable SSH password authentication
	ssh_pwauth: false
	
	# SSH host key settings
	#-----------------------
	ssh:
	  # Show SSH host keys and their fingerprints on console
	  emit_keys_to_console: true
	#
	# Don't show these SSH host key types on console (DSA is never shown)
	ssh_key_console_blacklist: ["ssh-ecdsa", "ssh-ed25519", "ssh-rsa"]
	#
	# Don't display SSH host keygen output including VisualArt
	ssh_quiet_keygen: true
	
	# Don't display users' SSH key fingerprints on console.
	no_ssh_fingerprints: true
	_SCRIPT_

  write_log "Setting up Users info" 2
  cat <<-_SCRIPT_ > /etc/cloud/cloud.cfg.d/02-users.cfg
	# /etc/cloud/cloud.cfg.d/02-users.cfg
	
	users:
	  - default
	_SCRIPT_

  write_log "Locking the root account" 4
  cat <<-_SCRIPT_ >> /etc/cloud/cloud.cfg.d/02-users.cfg
	  - name: root
	    lock_passwd: true
	_SCRIPT_

  write_log "Disabling cloud-init debugging" 2
  sed -i \\
    -E '\$!N; s/([handler_cloudLogHandler]\nclass=FileHandler\n[[:space:]]*)level=[A-Z]*/\1level=INFO/g ;P;D' \\
    /etc/cloud/cloud.cfg.d/05_logging.cfg
  sed -i \\
    -E '\$!N; s/([handler_cloudLogHandler]\nclass=handlers.SysLogHandler\n[[:space:]]*)level=[A-Z]*/\1level=INFO/g ;P;D' \\
    /etc/cloud/cloud.cfg.d/05_logging.cfg

  write_log "Setting up /etc/filesystems for VFAT mounts" 2
  {
    cat <<-_SCRIPT_ > /etc/filesystems
	#
	# /etc/filesystems
	#
	
	# Needed for cloud-init VFAT configuration mounts
	vfat
	_SCRIPT_
  }

  write_log "Creating cloud-init YAML files for physical machine"
  {
    write_log "Create example YAML files" 2
    mkdir /cidata/examples

    cat <<-_SCRIPT_ > /cidata/examples/meta-data
	instance-id: iid-local0
	_SCRIPT_

    cat <<-_SCRIPT_ > /cidata/examples/network-dhcp
	version: 2
	ethernets:
	  eth0:
	    dhcp4: yes
	    dhcp6: yes
	_SCRIPT_

    cat <<-_SCRIPT_ > /cidata/examples/network-static
	version: 2
	ethernets:
	  eth0:
	    addresses:
	      - 192.168.0.2/24
	    routes:
	      - to: 0.0.0.0
	        via: 192.168.0.1
	    mtu: 1500
	    wakeonlan: false
	_SCRIPT_

    cat <<-_SCRIPT_ > /cidata/examples/user-data
	#cloud-config
	
	apk_repos:
	  preserve_repositories: false
	  alpine_repo:
	    version: 'edge'
	    base_url: https://dl-cdn.alpinelinux.org/alpine
	    community_enabled: true
	    testing_enabled: true
	
	package_reboot_if_required: false
	package_update: false
	package_upgrade: false
	
	locale: \$locale
	timezone: \$timezone
	
	ntp:
	  enabled: true
	  servers:
	    - pool.ntp.org
	
	# Growpart & resize does not work for LUKS or LVM or LVM-on-LUKS
	# currently and also do not handle overprovisioning for flash-based
	# devices so this will be handled via runcmd instead.
	#
	growpart:
	  mode: off
	resize_rootfs: false
	
	runcmd:
	  # Grow LUKS partition
	  - growpart /dev/sda 3 >>/var/log/resize-storage.log 2>&1
	  #
	  # Grow LUKS to fill partition
	  - cryptsetup resize lukspart >>/var/log/resize-storage.log 2>&1
	  #
	  # Grow LVM PV to fill LUKS partition
	  - pvresize resize /dev/mapper/lukspart >>/var/log/resize-storage.log 2>&1
	  #
	  # Don't resize root LV at all
	  #
	  # Grow logs LV by 8M
	  - lvextend -L +8m /dev/mapper/vg0-logs >>/var/log/resize-storage.log 2>&1
	  #
	  # Resize underlying logs filesystem
	  - resize2fs /dev/mapper/vg0-logs >>/var/log/resize-storage.log 2>&1
	
	ssh:
	  # Whether to show either host keys or their fingerprints on console
	  emit_keys_to_console: false
	
	_SCRIPT_

    write_log "Creating meta-data" 2
    cp /cidata/examples/meta-data /cidata/meta-data

    write_log "Creating network-config" 2
    cp /cidata/examples/network-dhcp /cidata/network-config

    write_log "Creating user-data" 2
    cp /cidata/examples/user-data /cidata/user-data
  }
}

write_log "Installing kernel linux-lts"
{
  apk add linux-lts linux-firmware-none >> /chroot.log 2>&1

  _kernel_version=\$(get_kernel_version)
  _kernel_package_version=\$(get_kernel_package_version)
}

write_log "Configuring mkinitfs"
{
  write_log "Setting up mkinitfs.conf" 2

  sed -i -e \\
    "s|^features=\".*\"|features=\"base keymap usb ext4 lvm cryptkey cryptsetup physical-pc\"|" \\
    /etc/mkinitfs/mkinitfs.conf

  # Base
  {
    write_log "Setting up features.d/base.modules" 2
    cat <<-_SCRIPT_ >> /etc/mkinitfs/features.d/base.modules
	_SCRIPT_
  }

  # USB
  {
    :
  }

  # Ext4
  {
    :
  }

  # LVM
  {
    :
  }

  # Cryptsetup
  {
    :
  }

  # physical-pc
  {
    write_log "Setting up features.d/physical-pc.modules" 2
    cat <<-_SCRIPT_ > /etc/mkinitfs/features.d/physical-pc.modules
	kernel/drivers/acpi/button.ko*
	kernel/drivers/crypto/ccp
	kernel/drivers/char/hw_random/intel-rng.ko*
	kernel/drivers/gpu/drm/amd
	kernel/drivers/gpu/drm/tiny/bochs.ko*
	kernel/drivers/gpu/drm/i915
	kernel/drivers/gpu/drm/nouveau
	kernel/drivers/gpu/drm/radeon
	kernel/drivers/gpu/drm/tiny/simpledrm.ko*
	kernel/drivers/ata/ahci.ko*
	kernel/drivers/ata/ahci_platform.ko*
	kernel/drivers/ata/libahci.ko*
	kernel/drivers/ata/libahci_platform.ko*
	kernel/drivers/scsi/sd_mod.ko*
	_SCRIPT_

    # Sort and remove duplicate entries
    sort -u -o \\
      /etc/mkinitfs/features.d/physical-pc.modules \\
      /etc/mkinitfs/features.d/physical-pc.modules
  }

  write_log "Regenerating initramfs" 2
  mkinitfs "\$_kernel_version" >> /chroot.log 2>&1
}

write_log "Setup /etc/modules-load.d/ files"
{
  if ! grep -q af_packet /etc/modules; then
    cat <<-_SCRIPT_ > /etc/modules-load.d/network.conf
	af_packet
	_SCRIPT_
  fi

  if ! grep -q ipv6 /etc/modules; then
    cat <<-_SCRIPT_ >> /etc/modules-load.d/network.conf
	ipv6
	_SCRIPT_
  fi

  # Network
  mod_list="\$(check_list_of_modules_exist "r8169")"
  if [ -n "\$mod_list" ]; then
    write_log "Adding Network modules \$mod_list to /etc/modules-load.d/network.conf" 2
    cat <<-_SCRIPT_ >> /etc/modules-load.d/network.conf
	\$(echo_lines_from_comma_list "%s" "\$mod_list")
	_SCRIPT_
  fi

  # Storage
  mod_list="\$(check_list_of_modules_exist "nvme,sd_mod,sdhci,ses,uas,usb-storage")"
  if [ -n "\$mod_list" ]; then
    write_log "Adding Storage modules \$mod_list to /etc/modules-load.d/storage.conf" 2
    cat <<-_SCRIPT_ >> /etc/modules-load.d/storage.conf
	\$(echo_lines_from_comma_list "%s" "\$mod_list")
	_SCRIPT_
  fi
}

write_log "Selecting microcode packages to install"
{
  write_log "Selecting Intel CPU microcode" 2
  write_log "Installing microcode" 2
  apk add intel-ucode >> /chroot.log 2>&1

  write_log "Removing microcode module from modprobe blacklist" 2
  sed -i -E -e 's/^(blacklist microcode)$/#\1/' \
    /etc/modprobe.d/blacklist.conf
}
write_log "Selecting firmware packages to install"
{
  write_log "Selecting AMD, Intel & Nvidia graphics driver firmware" 2
  write_log "Selecting Realtek NIC firmware" 2
  write_log "Installing firmware" 2
  apk add linux-firmware-amdgpu linux-firmware-nouveau linux-firmware-radeon linux-firmware-i915 linux-firmware-rtl_nic >> /chroot.log 2>&1
}

write_log "Configuring Grub"
{
  mkdir -p /boot/grub

  # If relevant package is not already installed then install it
  if [ ! "\$(apk info -e losetup)" ]; then
    write_log "Installing losetup package for losetup" 2
    apk add losetup >> /chroot.log 2>&1
    losetup_package_installed=true
  fi

  write_log "Updating /etc/default/grub" 2
  {
    sed -i \\
      -e 's|^GRUB_DISABLE_RECOVERY=.*$|GRUB_DISABLE_RECOVERY=false|g' \\
      -e 's|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=5|g' \\
      -e '/^GRUB_CMDLINE_LINUX_DEFAULT=.*$/d' \\
      /etc/default/grub

    cmdline="rootfstype=ext4 console=tty0 \$(define_cmdline_for_luks_encryption)  quiet cryptkey"
    {
      echo "GRUB_CMDLINE_LINUX_DEFAULT=\"\$cmdline\""
      echo 'GRUB_ENABLE_LINUX_LABEL=false'
      echo 'GRUB_VIDEO_BACKEND=efi_gop'
      echo 'GRUB_DISABLE_LINUX_UUID=true'
      echo 'GRUB_DISABLE_OS_PROBER=true'
      echo 'GRUB_RECORDFAIL_TIMEOUT=20'
    } >> /etc/default/grub
    if ! grep -q "^GRUB_TERMINAL=" /etc/default/grub; then
      echo 'GRUB_TERMINAL=console' >> /etc/default/grub
    fi
    {
      echo 'GRUB_ENABLE_CRYPTODISK=y'
    } >> /etc/default/grub

    write_log "Set Grub menu colours" 4
    {
      echo 'GRUB_COLOR_NORMAL=white/blue'
      echo 'GRUB_COLOR_HIGHLIGHT=blue/white'
    } >> /etc/default/grub

    chmod g=,o= /etc/default/grub
  }

  write_log "Generating GRUB config" 2
  grub-mkconfig -o /boot/grub/grub.cfg >> /chroot.log 2>&1

  write_log "Checking GRUB config" 2
  grub-script-check /boot/grub/grub.cfg >> /chroot.log

  chmod g=,o= /boot/grub/grub.cfg
}

chmod 600 /boot/initramfs-lts

mkdir -p /boot/efi/EFI

write_log "Installing GRUB bootloader"
{
  write_log "Running GRUB installer" 2
  _grub_install_output=\$(grub-install \\
    --target=x86_64-efi --removable --efi-directory=/boot/efi --no-nvram --no-floppy \\
    2>&1 \\
    | sed -e '/^grub-install: info: copying .*$/d' \\
    | sed -e \\
        '/^grub-install: info: cannot open .*No such file or directory.$/d' \\
    | tee -a /chroot.log )
  if [ "\$(echo "\$_grub_install_output" | grep "error:")" != "" ]; then
    exit 1
  fi

  write_log "Storing grub-install options for later use" 2
  sed -i -E -e \\
    's|^[#](GRUB_INSTALL_OPTIONS=\")(.*)(\".*)$|\1--target=x86_64-efi --removable --efi-directory=/boot/efi --no-nvram --no-floppy\3|' \\
    /etc/grub-install-options.conf
  sed -i -E -e \\
    's|^[#](ESP_MOUNT_DIRECTORY=\")(.*)(\".*)$|\1/boot/efi\3|' \\
    /etc/grub-install-options.conf

  if [ -n "\$losetup_package_installed" ]; then
    write_log "Removing losetup package that was temporarily installed" 2
    apk del losetup >> /chroot.log 2>&1
  fi
}

write_log "Configuring various system services"
{
  write_log "Configuring ACPI" 2
  {
    write_log "Adjusting modprobe blacklist for button" 4
    {
      write_log "Removing ACPI button module from modprobe blacklist" 4
      sed -i -E -e 's/^(blacklist button)$/#\1/' \\
        /etc/modprobe.d/blacklist.conf

      write_log "Adding tiny_power_button module to modprobe blacklist" 4
      sed -i -E -e 's/^[#](blacklist tiny_power_button)$/\1/' \\
        /etc/modprobe.d/blacklist.conf
    }

    write_log "Enable acpid init.d service" 4
    {
      rc-update add acpid default
    } >> /chroot.log 2>&1
  }

  write_log "Configuring Cron daemon" 2
  {
    write_log "Configuring Busybox cron daemon" 4
    {
      :

      write_log "Enable Busybox cron init.d service" 6
      {
        rc-update add crond default
      } >> /chroot.log 2>&1
    }
  }

  write_log "Configuring DHCP client" 2
  {
    write_log "Configuring dhcpcd" 4
    {
      :
    }
  }

  write_log "Configuring getty daemons" 2
  {
    write_log "Enable normal console" 4
    {
      write_log "Enabling getty on normal console tty1" 6
      if grep -E "^#?tty1:" /etc/inittab >/dev/null; then
        sed -i -E -e \\
          's|^[#]tty1:.*|tty1::respawn:/sbin/getty 38400 tty1|g' \\
          /etc/inittab
      else
        printf \\
          '\n#Additional getty for tty1\ntty1::respawn:/sbin/getty 38400 tty1\n' \\
          >> /etc/inittab
      fi
    }

    write_log "Disabling unused gettys" 4
    sed -i -E -e 's|^tty([3-6].*)|#tty\1|g' /etc/inittab
  }

  write_log "Configuring NTP server" 2
  {
    write_log "Configuring Chrony NTP server" 4
    {
      write_log "Configuring cloud-init for NTP" 6
      {
        cat <<-_SCRIPT_ > /etc/cloud/cloud.cfg.d/02-ntp.cfg
	# /etc/cloud/cloud.cfg.d/02-ntp.cfg
	
	ntp:
	  enabled: true
	  ntp_client: chrony
	  pools:
	    - pool.ntp.org
	_SCRIPT_
      }

      write_log "Enable Chrony init.d service" 6
      {
        rc-update add chronyd default
      } >> /chroot.log 2>&1
    }
  }

  write_log "Configuring Syslog server" 2
  {
    write_log "Configuring Rsyslog server" 4
    {
      # Create empty file as rsyslog's logrotate config expects it
      :> /var/log/mail.log

      write_log "Enable rsyslog init.d service" 6
      {
        rc-update add rsyslog boot
      } >> /chroot.log 2>&1
    }
  }

  write_log "Configuring SSH server" 2
  {
    write_log "Configuring OpenSSH server" 4
    {
      write_log "Hardening OpenSSH server configuration" 6
      {
        write_log "Only generate ED25519 host key if missing on sshd startup" 8
        sed -i -e \\
          's/^[#]*key_types_to_generate=.*$/key_types_to_generate="ed25519"/' \\
          /etc/conf.d/sshd

        # Only modify sshd_config if existing setting is not as desired
        if ! grep -q -i -E \\
               '^subsystem[[:space:]]+sftp[[:space:]]+internal-sftp$' \\
               /etc/ssh/sshd_config; then
          write_log "Use built-in SFTP server" 8
          sed -i -e \\
            's|^[#]*subsystem[[:space:]]+sftp[[:space:]].*$|Subsystem  sftp  internal-sftp|' \\
            /etc/ssh/sshd_config
        fi

        write_log "Creating /etc/ssh/sshd_config.d/99-cadi.conf config file" 8
        {
          printf '#\n# /etc/ssh/sshd_config.d/99-cadi.conf\n#\n'
          printf '# Override settings from /etc/ssh/sshd_config.\n#\n'
          printf '# NOTE: the *first* occurrence of a setting in any file in\n'
          printf '# /etc/ssh/sshd_config.d/ takes precedence of same setting\n'
          printf '# in any later named files.\n#\n'
          printf '# Best to verify resultant config using "sshd -T | sort"\n\n'
        } > /etc/ssh/sshd_config.d/99-cadi.conf

        write_log "Only use ED25519 host key" 10
        {
          printf '\n# Only use ED25519 host key\n'
          printf 'HostKey  /etc/ssh/ssh_host_ed25519_key\n'
          printf 'HostKeyAlgorithms  ssh-ed25519\n'
        } >> /etc/ssh/sshd_config.d/99-cadi.conf

        write_log "Prevent challenge-response logins" 10
        write_log "Prevent keyboard-interactive logins" 10
        write_log "Prevent logins to accounts with empty passwords" 10
        write_log "Prevent root logins" 10
        write_log "Disable Agent forwarding" 10
        {
          printf '\n# Prevent challenge-response logins\n'
          printf 'ChallengeResponseAuthentication  no\n'
          printf '\n# Prevent keyboard-interactive logins\n'
          printf 'KbdInteractiveAuthentication  no\n'
          printf '\n# Prevent logins to accounts with empty passwords\n'
          printf 'PermitEmptyPasswords  no\n'
          printf '\n# Prevent root logins\n'
          printf 'PermitRootLogin  no\n'
          printf '\n# Disable Agent forwarding\n'
          printf 'AllowAgentForwarding  no\n'
        } >> /etc/ssh/sshd_config.d/99-cadi.conf

        write_log "Prevent password-based SSH logins" 10
        {
          printf '\n# Prevent password-based SSH logins\n'
          printf 'PasswordAuthentication  no\n'
        } >> /etc/ssh/sshd_config.d/99-cadi.conf


        write_log "Ensure only key-based authentication is enabled" 10
        {
          printf '\n# Ensure only key-based authentication is enabled\n'
          printf 'AuthenticationMethods "publickey"\n'
        } >> /etc/ssh/sshd_config.d/99-cadi.conf

        write_log "Enable both IPv4 and IPv6 access" 10
        {
          printf '\n# Enable IPv4 and IPv6 access\n'
          printf 'AddressFamily any\n'
          printf 'ListenAddress 0.0.0.0\n'
          printf 'ListenAddress ::\n'
        } >> /etc/ssh/sshd_config.d/99-cadi.conf

        write_log "Basic sshd secure configuration" 10
        {
          printf '\n# Limit Ciphers to relatively strong ones\n'
          printf 'Ciphers  chacha20-poly1305@openssh.com,aes256-gcm@openssh.com\n'
          printf '\n# limit KexAlgorithms to curve 25519\n'
          printf \\
            'KexAlgorithms  curve25519-sha256,curve25519-sha256@libssh.org\n'
          printf '\n# Limit MAC to Encrypt-then-MAC versions\n'
          printf 'MACS  hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com\n'
          printf '\n# Only accept relatively strong public key types\n'
          printf \\
            'PubkeyAcceptedKeyTypes  ssh-ed25519,sk-ssh-ed25519@openssh.com,rsa-sha2-512,rsa-sha2-256\n'
        } >> /etc/ssh/sshd_config.d/99-cadi.conf
      }

      write_log "Enable OpenSSH init.d service" 6
      {
        rc-update add sshd default
      } >> /chroot.log 2>&1
    }
  }

  write_log "Configuring console-only user account" 2
  {
    write_log "Creating 'console-only' group" 4
    addgroup console-only >> /chroot.log

    write_log "Configuring 'localadmin' user account" 4
    {
      write_log "Creating 'localadmin' user for console-only access" 6
      adduser -g "User for console-only access" -D localadmin >> /chroot.log

      write_log "Fix-up permissions for localadmin home directory" 6
      chmod g-rx,o-rx /home/localadmin

      write_log "Unlocking user account 'localadmin' (for password access)" 6
      usermod -p "" localadmin >> /chroot.log 2>&1 || true

      write_log \\
        "Setting up password-less doas access for 'console-only' group" 6
      {
        write_log \\
          "Setting up doas for 'console-only' group" 8
        {
          printf \\
            '\n# Enable password-less access for members of group '\''%s'\''\n' \\
            "console-only"
          printf 'permit nopass :%s\n' "console-only"
        } >> /etc/doas.conf

        write_log "Adding 'localadmin' user to 'console-only' group" 8
        addgroup localadmin console-only >> /chroot.log
      }
    }

    write_log "Disabling SSH access for users in 'console-only' group" 4
    {
      {
        printf '\n# Deny SSH access for users in '\''%s'\'' group\n' \\
          "console-only"
        printf 'DenyGroups %s\n' "console-only"
      } >> /etc/ssh/sshd_config.d/99-cadi.conf
    }
  }

  write_log "Enable lvm init.d service" 2
  {
    rc-update add lvm boot
  } >> /chroot.log 2>&1

  write_log "Configuring acct" 2
  {
    write_log "Enable acct init.d service" 4
    {
      rc-update add acct default
    } >> /chroot.log 2>&1
  }

  write_log "Configuring hd-idle daemon" 2
  {
    sed -i -e 's|[#]DISK=".*$|DISK="/dev/sda"|g' /etc/conf.d/hd-idle

    write_log "Enable hd-idle init.d service" 4
    {
      rc-update add hd-idle default
    } >> /chroot.log 2>&1
  }

  write_log "Configuring Smartmontools daemon" 2
  {
    write_log "Enable smartd init.d service" 4
    {
      rc-update add smartd default
    } >> /chroot.log 2>&1
  }
}

apk info -v | sort > /final-packages.list

write_log "Clearing APK cache"
rm /var/cache/apk/*

write_debug_log "Final disk space usage:"
busybox df -k >> /chroot.log

EOT

#############################################################################
##		End of Chroot section
#############################################################################

cat "$chroot_dir"/chroot.log >> "$logfile"
rm "$chroot_dir"/chroot.log

write_log "Finished chroot section"

write_log "Removing temporary /etc/resolv.conf from chroot filesystem"
rm "$chroot_dir"/etc/resolv.conf

mv "$chroot_dir"/final-packages.list \
  ./"$(basename -s .log $logfile)".final-packages

write_log "Cleaning up"
normal_cleanup

write_log "Copying image from ramdisk to final location"
cp "$image_full_filename" "$images_dir/"
sync "$images_dir"/"$image_filename"
rm "$image_full_filename"
sync -f "$ramdisk_dir"
unmount_ramdisk

exit
