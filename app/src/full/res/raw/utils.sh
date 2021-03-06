db_sepatch() {
  magiskpolicy --live 'create magisk_file' 'attradd magisk_file mlstrustedobject' \
  'allow * magisk_file file *' 'allow * magisk_file dir *' \
  'allow magisk_file * filesystem associate'
}

db_clean() {
  local USERID=$1
  local DIR="/sbin/.core/db-${USERID}"
  umount -l /data/user*/*/*/databases/su.db $DIR $DIR/*
  rm -rf $DIR
  [ "$USERID" = "*" ] && rm -fv /data/adb/magisk.db*
}

db_init() {
  # Temporary let the folder rw by anyone
  chcon u:object_r:magisk_file:s0 /data/adb
  chmod 777 /data/adb
}

db_restore() {
  chmod 700 /data/adb
  magisk --restorecon
}

db_setup() {
  local USER=$1
  local USERID=$(($USER / 100000))
  local DIR=/sbin/.core/db-${USERID}
  mkdir -p $DIR
  touch $DIR/magisk.db
  mount -o bind /data/adb/magisk.db $DIR/magisk.db
  rm -f /data/adb/magisk.db-*
  chcon u:object_r:magisk_file:s0 $DIR $DIR/*
  chmod 700 $DIR
  chown $USER.$USER $DIR
  chmod 666 $DIR/*
}

env_check() {
  for file in busybox magisk magiskboot magiskinit util_functions.sh boot_patch.sh; do
    [ -f /data/adb/magisk/$file ] || return 1
  done
  return 0
}

fix_env() {
  cd /data/adb/magisk
  sh update-binary extract
  rm -f update-binary magisk.apk
  cd /
  rm -rf /sbin/.core/busybox/*
  /sbin/.core/mirror/bin/busybox --install -s /sbin/.core/busybox
}

direct_install() {
  rm -rf /data/adb/magisk/* 2>/dev/null
  mkdir -p /data/adb/magisk 2>/dev/null
  chmod 700 /data/adb
  cp -rf $1/* /data/adb/magisk
  rm -rf /data/adb/magisk/new-boot.img
  echo "- Flashing new boot image"
  flash_image $1/new-boot.img $2
  if [ $? -ne 0 ]; then
    echo "! Insufficient partition size"
    return 1
  fi
  rm -rf $1
  return 0
}

mm_patch_dtbo() {
  if $KEEPVERITY; then
    return 1
  else
    find_dtbo_image
    patch_dtbo_image
  fi
}

restore_imgs() {
  local SHA1=`cat /.backup/.sha1`
  [ -z $SHA1 ] && local SHA1=`grep_prop #STOCKSHA1`
  [ -z $SHA1 ] && return 1
  local STOCKBOOT=/data/stock_boot_${SHA1}.img.gz
  local STOCKDTBO=/data/stock_dtbo.img.gz
  [ -f $STOCKBOOT ] || return 1

  find_boot_image
  find_dtbo_image

  if [ -f $STOCKDTBO -a -b "$DTBOIMAGE" ]; then
    flash_image $STOCKDTBO $DTBOIMAGE
  fi
  if [ -f $STOCKBOOT -a -b "$BOOTIMAGE" ]; then
    flash_image $STOCKBOOT $BOOTIMAGE
    return 0
  fi
  return 1
}

post_ota() {
  cd $1
  chmod 755 bootctl
  ./bootctl hal-info || return
  [ `./bootctl get-current-slot` -eq 0 ] && SLOT_NUM=1 || SLOT_NUM=0
  ./bootctl set-active-boot-slot $SLOT_NUM
  echo '${0%/*}/../bootctl mark-boot-successful;rm -f ${0%/*}/../bootctl $0' > post-fs-data.d/post_ota.sh
  chmod 755 post-fs-data.d/post_ota.sh
  cd /
}
