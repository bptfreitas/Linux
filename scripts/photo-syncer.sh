#!/usr/bin

[[ ! -d "${SRC_PHOTO_DIR}" ]] && {  echo "[ERROR] \$SRC_PHOTO_DIR not found"; exit -1; }
[[ ! -d "${DST_PHOTO_DIR}" ]] && {  echo "[ERROR] \$DST_PHOTO_DIR not found"; exit -1; }

rsync -ruv "${SRC_PHOTO_DIR}" "${DST_PHOTO_DIR}"