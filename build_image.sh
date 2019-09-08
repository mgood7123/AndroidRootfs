echo cleaning...
rm -rf build

echo generating file_contexts...
mkdir build
cd build

echo "dependancy: sectxfile_nl_intermediates/sectxfile_nl"

mkdir sectxfile_nl_intermediates

echo > sectxfile_nl_intermediates/sectxfile_nl

mkdir file_contexts.bin_intermediates

echo "dependancy: system/sepolicy/vendor/file_contexts"
echo "dependancy: system/sepolicy/private/file_contexts"

mkdir sepolicy
mkdir sepolicy/vendor
mkdir sepolicy/private
cp ../../system/sepolicy/vendor/file_contexts sepolicy/vendor/file_contexts
cp ../../system/sepolicy/private/file_contexts sepolicy/private/file_contexts

echo generating file_contexts.device.tmp

m4 -s  sepolicy/vendor/file_contexts sectxfile_nl_intermediates/sectxfile_nl > file_contexts.bin_intermediates/file_contexts.device.tmp

echo checking file_contexts.device.tmp

echo "dependancy: out/target/product/phhgsi_arm64_a/obj/ETC/sepolicy_intermediates/sepolicy"

mkdir sepolicy_intermediates

cp ../../out/target/product/phhgsi_arm64_a/obj/ETC/sepolicy_intermediates/sepolicy sepolicy_intermediates/sepolicy

../../out/host/linux-x86/bin/checkfc -e sepolicy_intermediates/sepolicy file_contexts.bin_intermediates/file_contexts.device.tmp

if [[ $? == 0 ]]
    then
        echo file_contexts.device.tmp passed
        echo generating file_contexts.device.sorted.tmp

        ../../out/host/linux-x86/bin/fc_sort \
        file_contexts.bin_intermediates/file_contexts.device.tmp > file_contexts.bin_intermediates/file_contexts.device.sorted.tmp

        echo "dependancy: device/phh/treble/sepolicy/file_contexts"
        mkdir -p device/phh/treble/sepolicy
        cp ../../device/phh/treble/sepolicy/file_contexts device/phh/treble/sepolicy/file_contexts

        echo generating file_contexts.local.tmp

        m4 -s sepolicy/private/file_contexts \
        sectxfile_nl_intermediates/sectxfile_nl \
        device/phh/treble/sepolicy/file_contexts \
        > file_contexts.bin_intermediates/file_contexts.local.tmp

        echo generating file_contexts.concat.tmp

        m4 -s file_contexts.bin_intermediates/file_contexts.local.tmp \
        file_contexts.bin_intermediates/file_contexts.device.sorted.tmp \
        > file_contexts.bin_intermediates/file_contexts.concat.tmp

        echo checking file_contexts.concat.tmp

        ../../out/host/linux-x86/bin/checkfc sepolicy_intermediates/sepolicy file_contexts.bin_intermediates/file_contexts.concat.tmp

        if [[ $? == 0 ]]
            then
                echo file_contexts.concat.tmp passed
                echo generating file_contexts.bin

                ../../out/host/linux-x86/bin/sefcontext_compile -o \
                file_contexts.bin_intermediates/file_contexts.bin file_contexts.bin_intermediates/file_contexts.concat.tmp

                if [[ $? == 0 ]]
                    then
                        echo generated file_contexts.bin
                        # mkbootfs needs to be made as it is not present after the end of a successfull GSI build
                        echo "dependancy: ../../out/host/linux-x86/bin/mkbootfs"
                        mkdir -p mkbootfs_intermediates/
                        CWD=$(pwd)
                        cd ../../
                        AOSP=$(pwd)
                        for f in \
                            out/host/linux-x86/obj/SHARED_LIBRARIES/libcutils_intermediates/export_includes \
                            out/host/linux-x86/obj/SHARED_LIBRARIES/libc++_intermediates/export_includes \
                            out/host/linux-x86/obj/STATIC_LIBRARIES/libcompiler_rt-extras_intermediates/export_includes
                                do
                                    cat "$f" >> $CWD/mkbootfs_intermediates/import_includes
                        done
			# using ccache causes it to produce a build error due to an extention of strcmp
			PWD=/proc/self/cwd prebuilts/clang/host/linux-x86/clang-4691093/bin/clang \
			-I system/core/cpio -I $CWD/mkbootfs_intermediates -I libnativehelper/include_jni \
                        $(cat $CWD/mkbootfs_intermediates/import_includes) \
			-I system/core/include -I system/media/audio/include -I hardware/libhardware/include -I hardware/libhardware_legacy/include \
			-I hardware/ril/include -I libnativehelper/include -I frameworks/native/include -I frameworks/native/opengl/include \
			-I frameworks/av/include  -c  -Wa,--noexecstack -fPIC -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=2 -fstack-protector \
			-D__STDC_FORMAT_MACROS -D__STDC_CONSTANT_MACROS --gcc-toolchain=prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.15-4.8 \
			--sysroot prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.15-4.8/sysroot -fstack-protector-strong -m64 -DANDROID \
			-fmessage-length=0 -W -Wall -Wno-unused -Winit-self -Wpointer-arith -no-canonical-prefixes -DNDEBUG -UDEBUG -fno-exceptions \
			-Wno-multichar -O2 -g -fno-strict-aliasing -fdebug-prefix-map=/proc/self/cwd= -D__compiler_offsetof=__builtin_offsetof \
			-Werror=int-conversion -Wno-reserved-id-macro -Wno-format-pedantic -Wno-unused-command-line-argument -fcolor-diagnostics \
			-Wno-expansion-to-defined -Wno-zero-as-null-pointer-constant -fdebug-prefix-map=$PWD/=   -target x86_64-linux-gnu \
			-Bprebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.15-4.8/x86_64-linux/bin   -std=gnu99  -Werror -fPIE -D_USING_LIBCXX \
			-DANDROID_STRICT   -Werror=int-to-pointer-cast -Werror=pointer-to-int-cast -Werror=address-of-temporary -Werror=return-type \
			-Wno-tautological-constant-compare -Wno-null-pointer-arithmetic -Wno-enum-compare -Wno-enum-compare-switch -MD -MF \
			$CWD/mkbootfs_intermediates/mkbootfs.d -o $CWD/mkbootfs_intermediates/mkbootfs.o system/core/cpio/mkbootfs.c &&

			prebuilts/misc/linux-x86/ccache/ccache prebuilts/clang/host/linux-x86/clang-4691093/bin/clang++ \
			$CWD/mkbootfs_intermediates/mkbootfs.o -Wl,--whole-archive  -Wl,--no-whole-archive \
			out/host/linux-x86/obj/STATIC_LIBRARIES/libcompiler_rt-extras_intermediates/libcompiler_rt-extras.a \
			out/host/linux-x86/obj/lib/libcutils.so out/host/linux-x86/obj/lib/libc++.so \
			-Wl,-rpath-link=$AOSP/out/host/linux-x86/obj/lib  -Wl,-rpath,$AOSP/out/host/linux-x86/lib64 \
                        -Wl,-rpath,$AOSP/out/host/linux-x86/lib64 \
			-Wl,-z,noexecstack -Wl,-z,relro -Wl,-z,now -Wl,--no-undefined-version \
			--gcc-toolchain=prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.15-4.8 \
			--sysroot prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.15-4.8/sysroot -m64 \
			-Bprebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.15-4.8/lib/gcc/x86_64-linux/4.8 \
			-Lprebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.15-4.8/lib/gcc/x86_64-linux/4.8 \
			-Lprebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.15-4.8/x86_64-linux/lib64 \
			-target x86_64-linux-gnu -Bprebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.15-4.8/x86_64-linux/bin \
			-pie -nodefaultlibs -Wl,--no-undefined \
			-o $CWD/mkbootfs_intermediates/mkbootfs -ldl -lpthread -lm -lrt  -lgcc_s -lgcc -lc -lgcc_s -lgcc
                        cd $CWD

                        echo constructing ramdisk

                        mkbootfs_intermediates/mkbootfs -d ../image/system ../image/root | ../../out/host/linux-x86/bin/minigzip > ramdisk.img

                        echo constructing system image
                        mkdir systemimage_intermediates
                        echo "ext_mkuserimg=mkuserimg_mke2fs.sh" >> systemimage_intermediates/system_image_info.txt
                        echo "fs_type=ext4" >> systemimage_intermediates/system_image_info.txt
                        echo "system_size=2080374784" >> systemimage_intermediates/system_image_info.txt
                        echo "extfs_sparse_flag=-s" >> systemimage_intermediates/system_image_info.txt
                        echo "squashfs_sparse_flag=-s" >> systemimage_intermediates/system_image_info.txt
                        echo "selinux_fc=$(pwd)/file_contexts.bin_intermediates/file_contexts.bin" >> systemimage_intermediates/system_image_info.txt
                        echo "skip_fsck=true" >> systemimage_intermediates/system_image_info.txt
                        input_directory=$(pwd)/../image/system
                        properties_file=$(pwd)/systemimage_intermediates/system_image_info.txt
                        output_image=$(pwd)/system.img
                        target_output_directory=$(pwd)/../image/system
                        PATH=$AOSP/out/host/linux-x86/bin/:$PATH
                        ../../build/make/tools/releasetools/build_image.py $input_directory $properties_file $output_image $target_output_directory
                        if [ $? == 0 ]
                            then
                                echo merging ramdisk.img and system.img into system_image.img
                                simg2img ramdisk.img system.img system_image.img
                                if [ $? == 0 ]
                                    then
                                        echo merged ramdisk.img and system.img into system_image.img successfully
                                    else echo failed to merge ramdisk.img and system.img into system_image.img
                                fi
                            else echo failed to construct system image
                        fi
                    else echo failed to generate file_contexts.bin
                fi
            else echo file_contexts.concat.tmp failed
        fi
    else echo file_contexts.device.tmp failed
fi
