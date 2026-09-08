. /lib/upgrade/common.sh

glinet_get_fit_part() {
	local image="$1"
	local name="$2"

	dumpimage -l "$image" 2>/dev/null | \
		sed -n "s/^[[:space:]]*Image \([0-9][0-9]*\) ($name)$/\1/p"
}

glinet_emmc_check_image() {
	[ "$(identify_magic_long "$(get_magic_long "$1")")" != "fit" ] && return 0

	local hlos=$(glinet_get_fit_part "$1" hlos)
	local rootfs=$(glinet_get_fit_part "$1" rootfs)
	[ -n "$hlos" ] && [ -n "$rootfs" ] && return 0

	v "The factory image must contain hlos and rootfs sections."
	return 1
}

glinet_emmc_part_size() {
	local device="$1"

	echo $(( $(cat "/sys/class/block/${device##*/}/size" 2>/dev/null || echo 0) * 512 ))
}

# Extract one FIT section to /tmp and verify it is non-empty and fits
# its target partition. No flash is touched here.
glinet_emmc_extract_fit_part() {
	local image="$1"
	local part="$2"
	local device="$3"
	local name="$4"
	local output="/tmp/glinet-emmc-$name.bin"
	local size part_size

	v "Extracting and verifying $name"
	rm -f "$output"
	dumpimage -T flat_dt -p "$part" -o "$output" "$image" && [ -s "$output" ] || {
		rm -f "$output"
		v "Failed to extract the $name section from the image."
		return 1
	}

	size=$(( $(wc -c < "$output") ))
	part_size=$(glinet_emmc_part_size "$device")
	[ "$part_size" -gt 0 ] && [ "$size" -le "$part_size" ] || {
		rm -f "$output"
		v "$name ($size bytes) does not fit $device ($part_size bytes)."
		return 1
	}
}

glinet_emmc_flash_extracted() {
	local device="$1"
	local name="$2"
	local output="/tmp/glinet-emmc-$name.bin"
	local ret

	v "Flashing $name to $device"
	dd if="$output" of="$device" bs=1M conv=fsync
	ret=$?
	rm -f "$output"
	return "$ret"
}

glinet_emmc_do_fit_upgrade() {
	local image="$1"
	local hlos=$(glinet_get_fit_part "$image" hlos)
	local rootfs=$(glinet_get_fit_part "$image" rootfs)
	local wifi_fw=$(glinet_get_fit_part "$image" wifi_fw)
	local hlos_dev=$(find_mmc_part "$CI_KERNPART" "$CI_ROOTDEV")
	local rootfs_dev=$(find_mmc_part "$CI_ROOTPART" "$CI_ROOTDEV")
	local wifi_fw_dev

	[ -n "$wifi_fw" ] && wifi_fw_dev=$(find_mmc_part "0:WIFIFW" "$CI_ROOTDEV")
	[ -n "$hlos" ] && [ -n "$rootfs" ] && \
		[ -n "$hlos_dev" ] && [ -n "$rootfs_dev" ] || {
		v "Unable to find the required GL.iNet image sections or eMMC partitions."
		return 1
	}
	[ -z "$wifi_fw" ] || [ -n "$wifi_fw_dev" ] || {
		v "Unable to find the GL.iNet Wi-Fi firmware partition."
		return 1
	}

	# Extract and size-check every section before the first destructive
	# write, so an extraction failure, /tmp exhaustion or an oversized
	# section aborts while the installed system is still bootable.
	glinet_emmc_extract_fit_part "$image" "$rootfs" "$rootfs_dev" rootfs || return 1
	glinet_emmc_extract_fit_part "$image" "$hlos" "$hlos_dev" hlos || {
		rm -f /tmp/glinet-emmc-rootfs.bin
		return 1
	}
	[ -z "$wifi_fw" ] || glinet_emmc_extract_fit_part "$image" "$wifi_fw" "$wifi_fw_dev" wifi_fw || {
		rm -f /tmp/glinet-emmc-rootfs.bin /tmp/glinet-emmc-hlos.bin
		return 1
	}

	# Let emmc_copy_config find the config backup location (64 KiB
	# aligned, matching ROOTDEV_OVERLAY_ALIGN in libfstools).
	export EMMC_ROOT_DEV="$rootfs_dev"
	export EMMC_ROOTFS_BLOCKS=$(( ($(wc -c < /tmp/glinet-emmc-rootfs.bin) + 511) / 512 ))
	EMMC_ROOTFS_BLOCKS=$(( (EMMC_ROOTFS_BLOCKS + 127) & ~127 ))

	# Destructive phase. Invalidate the kernel first so a power loss
	# never boots a half-written system, and write it back last.
	dd if=/dev/zero of="$hlos_dev" bs=512 count=8 conv=fsync || return 1
	glinet_emmc_flash_extracted "$rootfs_dev" rootfs || return 1
	[ -z "$wifi_fw" ] || \
		glinet_emmc_flash_extracted "$wifi_fw_dev" wifi_fw || return 1
	glinet_emmc_flash_extracted "$hlos_dev" hlos
}

glinet_emmc_do_upgrade() {
	case "$(identify_magic_long "$(get_magic_long "$1")")" in
	fit)
		glinet_emmc_do_fit_upgrade "$1"
		;;
	*)
		emmc_do_upgrade "$1"
		;;
	esac
}
