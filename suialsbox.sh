#!/bin/bash
clear
sudo apt install bzip2 gcc make unzip -y
ROOT_DIR=$(pwd)
NDK_ZIP="android-ndk-r29-linux.zip"
NDK_DIR="$ROOT_DIR/android-ndk-r29"
BUSYBOX_DIR="$ROOT_DIR/busybox"
export NDK="$NDK_DIR"
export TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin"
export TARGET="aarch64-linux-android"
export API="35"
if [ "$1" = "rebuild" ]; then
if [ ! -d "$BUSYBOX_DIR" ]; then
exit 1
fi
cd "$BUSYBOX_DIR"
else
if [ ! -d "$BUSYBOX_DIR" ]; then
git clone https://git.busybox.net/busybox
fi
if [ ! -d "$NDK_DIR" ]; then
if [ ! -f "$NDK_ZIP" ]; then
wget https://dl.google.com/android/repository/android-ndk-r29-linux.zip
fi
unzip "$NDK_ZIP"
fi
clear
if [ -f "$ROOT_DIR/.config" ]; then
cp "$ROOT_DIR/.config" "$BUSYBOX_DIR/"
fi
cd "$BUSYBOX_DIR"
git checkout .
sed -i '2i #ifdef __ANDROID__\n#include <unistd.h>\nstatic long gethostid(void) { return 0; }\n#endif' coreutils/hostid.c
find console-tools -name "*.c" -exec sed -i 's/sys\/kd.h/linux\/kd.h/g' {} +
sed -i '2i #ifdef __ANDROID__\n#ifndef GIO_UNIMAP\n#define GIO_UNIMAP 0x4B66\n#endif\n#endif' console-tools/loadfont.c
sed -i '2i #ifdef __ANDROID__\n#include <utmp.h>\nstatic void updwtmpx(const char *filename, const struct utmpx *ut) { }\n#endif' init/halt.c
sed -i '2i #ifdef __ANDROID__\n#include <utmpx.h>\nstatic void updwtmpx(const char *f, const struct utmpx *u) { }\n#endif' libbb/utmp.c
sed -i '1i #ifndef _EXPLICIT_BZERO_PATCH_\n#define _EXPLICIT_BZERO_PATCH_\n#ifdef __ANDROID__\n#include <string.h>\n#include <stddef.h>\nstatic inline void explicit_bzero(void *s, size_t n) {\n    memset(s, 0, n);\n    __asm__ __volatile__("" : : "r"(s) : "memory");\n}\n#endif\n#endif' libbb/yescrypt/y.c
cat << 'EOF' > android_su_patch.h
#ifdef __ANDROID__
#include <stdio.h>
#include <string.h>
static FILE *__shells_fp = NULL;
static char *getusershell(void) {
    static char line[256];
    if (!__shells_fp) __shells_fp = fopen("/etc/shells", "r");
    if (!__shells_fp) return (char *)"/system/bin/sh";
    while (fgets(line, sizeof(line), __shells_fp)) {
        char *p = strchr(line, '\n');
        if (p) *p = '\0';
        if (line[0] == '/') return line;
    }
    return NULL;
}
static void endusershell(void) {
    if (__shells_fp) { fclose(__shells_fp); __shells_fp = NULL; }
}
#endif
EOF
sed -i '20r android_su_patch.h' loginutils/su.c
rm android_su_patch.h
sed -i '1i #include <sys/syscall.h>' miscutils/adjtimex.c
sed -i 's/ret = adjtimex(&txc)/ret = syscall(__NR_adjtimex, \&txc)/g' miscutils/adjtimex.c
sed -i 's/<sys\/kd.h>/<linux\/kd.h>/g' miscutils/conspy.c
sed -i '20a #ifdef __ANDROID__\n#define utmpxname(x) utmpname(x)\n#endif' miscutils/runlevel.c
sed -i '1i #ifdef __ANDROID__\n#include <netinet/ether.h>\nstatic int ether_hostton(const char *hostname __attribute__((unused)), struct ether_addr *addr __attribute__((unused))) { return -1; }\n#endif' networking/ether-wake.c
sed -i '131,135s/^/\/\//' networking/ifconfig.c
sed -i '61,65s/^/\/\//' networking/interface.c
sed -i '1i #ifdef __ANDROID__\n#include <linux/rtnetlink.h>\n#include <linux/pkt_sched.h>\nstruct tc_cbq_lssopt { unsigned char change, flags, ewma_log, level; __u32 maxidle, minidle; __u32 offtime; };\nstruct tc_cbq_wrropt { unsigned char flags, priority, cpriority, reserved; __u32 allot, weight; };\nstruct tc_cbq_fopt { __u32 split; __u32 defmap; __u32 defpriority; };\nstruct tc_cbq_ovl { unsigned char strategy, priority, pad2, pad3; __u32 penalty; };\nenum { TCA_CBQ_UNSPEC, TCA_CBQ_LSSOPT, TCA_CBQ_WRROPT, TCA_CBQ_FOPT, TCA_CBQ_OVL_STRATEGY, TCA_CBQ_RATE, TCA_CBQ_RTAB, TCA_CBQ_POLICE, __TCA_CBQ_MAX, };\n#define TCA_CBQ_MAX (__TCA_CBQ_MAX - 1)\n#define TCF_CBQ_LSS_BOUNDED 1\n#define TCF_CBQ_LSS_ISOLATED 2\n#define TC_CBQ_MAXPRIO 8\n#endif' networking/tc.c
sed -i 's/sigisemptyset(&G.pending_set)/(*(const long *)\&G.pending_set == 0L)/g' shell/hush.c
sed -i '1i #ifdef __ANDROID__\n#define setbit(a,i) ((a)[(i)/8] |= (1<<((i)%8)))\n#define clrbit(a,i) ((a)[(i)/8] &= ~(1<<((i)%8)))\n#endif' util-linux/fsck_minix.c
sed -i '35,40s/^/\/\//' util-linux/ipcrm.c
sed -i '78,83s/^/\/\//' util-linux/ipcs.c
sed -i '1i #ifdef __ANDROID__\n#define setbit(a,i) ((a)[(i)/8] |= (1<<((i)%8)))\n#define clrbit(a,i) ((a)[(i)/8] &= ~(1<<((i)%8)))\n#endif' util-linux/mkfs_minix.c
sed -i '/#include <mntent.h>/a #ifdef __ANDROID__\nstatic int addmntent(FILE *fp __attribute__((unused)), const struct mntent *mnt __attribute__((unused))) { return 0; }\n#endif' util-linux/mount.c
sed -i '1i #ifdef __ANDROID__\n#include <sys/syscall.h>\n#include <unistd.h>\n#define swapon(path, flags) syscall(__NR_swapon, path, flags)\n#define swapoff(path) syscall(__NR_swapoff, path)\n#define SWAP_FLAG_PREFER 0x8000\n#define SWAP_FLAG_PRIO_MASK 0x7fff\n#endif' util-linux/swaponoff.c
sed -i 's/\bgetsid\b/getsid_bb/g' libbb/missing_syscalls.c
sed -i 's/\badjtimex\b/adjtimex_bb/g' libbb/missing_syscalls.c
sed -i 's/\bsethostname\b/sethostname_bb/g' libbb/missing_syscalls.c
sed -i 's/\bstrchrnul\b/strchrnul_bb/g' libbb/platform.c
fi
REAL_LIBM=$(find "$TOOLCHAIN/../sysroot" -name libm.a | grep aarch64 | head -n 1)
cp "$REAL_LIBM" ./libm.a
"$TOOLCHAIN/llvm-ar" rcs libresolv.a
make clean
make -j$(nproc) CC="$TOOLCHAIN/${TARGET}${API}-clang" AR="$TOOLCHAIN/llvm-ar" NM="$TOOLCHAIN/llvm-nm" RANLIB="$TOOLCHAIN/llvm-ranlib" STRIP="$TOOLCHAIN/llvm-strip" EXTRA_CFLAGS="-Os -fPIC -flto -fdata-sections -ffunction-sections -fno-unwind-tables -fno-asynchronous-unwind-tables -fno-stack-protector -fomit-frame-pointer -D__ANDROID__ -Wno-unused-command-line-argument" EXTRA_LDFLAGS="-flto -Wl,--gc-sections -Wl,--icf=all -Wl,-z,max-page-size=16384 -Wl,--strip-all -Wl,--exclude-libs,ALL" LDLIBS="m c dl"
$TOOLCHAIN/llvm-strip --strip-all --remove-section=.comment --remove-section=.note* busybox
du -h busybox
file busybox
readelf -h busybox | grep Type