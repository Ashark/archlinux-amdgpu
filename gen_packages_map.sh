#!/bin/bash

# This script prepares a packages mapping dict for using in gen-PKGBUILD.py
echo "# Generated with ./gen_packages_map.sh > packages_map.py"
echo -e "# for driver version `sed -n 2p Packages-extracted | cut -f 2 -d " "`\n"

echo "packages_map = {"
# get list of deb-metapackages:
cat Packages-extracted | grep -vE "Filename|Size|MD5sum|SHA1|SHA256|Priority|Maintainer|Version|Description|^ +" | grep -B4 "Section: metapackages" | grep -vE "Depends:|Section:" > tmp_Packages.txt
echo > tmp_deb_metapackages_list.txt

while read line; do
    if [[ $line =~ ^Package* ]]; then pkg=$(echo $line | sed "s/^Package: //"); continue; fi
    if [[ $line =~ ^Architecture* ]]; then
        arch=$(echo $line | sed "s/^Architecture: //")
        if [[ $arch == i386 ]]; then arch=":i386"; else arch=""; fi
        echo "$pkg$arch" >> tmp_deb_metapackages_list.txt; continue;
    fi
done < tmp_Packages.txt
rm tmp_Packages.txt


cat Packages-extracted | grep Package | cut -f2 -d " " > tmp_all_presented_debian_packages.txt
prev=""; for line in $(cat tmp_all_presented_debian_packages.txt); do if [[ $prev != $line ]]; then echo $line; else echo $line:i386; fi; prev=$line; done > tmp_renamed_deb_32bit_packages.txt
echo > tmp_non_hwe_list.txt
if grep amdgpu-hwe tmp_renamed_deb_32bit_packages.txt > /dev/null; then # hwe version presented
    grep hwe tmp_renamed_deb_32bit_packages.txt | sed 's/-hwe//' > tmp_non_hwe_list.txt
fi

shopt -s extglob # needed for expanding syntax in case patterns
for line in $(cat tmp_renamed_deb_32bit_packages.txt); do
    str="    '$line': "; comment="";
    if [[ $line != *"i386" ]]; then archpkg=$line; else archpkg="lib32-${line//:i386/}"; fi;
    ##if [[ $archpkg == *"-dev" ]]; then archpkg=${archpkg//-dev/}; fi; # disable for now, I will combine packages later, but now I will make 1:1 conversion

    if grep -Fx $line tmp_non_hwe_list.txt > /dev/null; then archpkg=None; comment="disabled_because_hwe_version_is_available"; fi;

    if [[ $archpkg == *"-hwe"* ]]; then archpkg=${archpkg//-hwe/}; fi;
 
    if grep $line tmp_deb_metapackages_list.txt > /dev/null && [[ $archpkg != None ]]; then archpkg="$archpkg-meta" comment="mapped_manually"; fi;

    case $line in
         amdgpu@(-dkms|-dkms-firmware||-hwe|-lib32)\
        |amdgpu-lib@(|-hwe)\
        |glamor-amdgpu@(|-dev)\
        |gst-omx-amdgpu@(|:i386)\
        |libegl1-amdgpu-mesa@(|:i386|-dev|-dev:i386)\
        |libegl1-amdgpu-mesa-drivers@(|:i386)\
        |libgbm-amdgpu-dev@(|:i386)\
        |libgbm1-amdgpu@(|:i386)\
        |libgl1-amdgpu-mesa@(-dev|-dev:i386|-dri|-dri:i386|-glx|-glx:i386)\
        |libglapi-amdgpu-mesa@(|:i386)\
        |libgles1-amdgpu-mesa@(|:i386|-dev|-dev:i386)\
        |libgles2-amdgpu-mesa@(|:i386|-dev|-dev:i386)\
        |libllvm10.0-amdgpu@(|:i386)\
        |libosmesa6-amdgpu@(|:i386|-dev|-dev:i386)\
        |libxatracker2-amdgpu@(|:i386)\
        |mesa-amdgpu-omx-drivers@(|:i386)\
        |mesa-amdgpu-va-drivers@(|:i386)\
        |mesa-amdgpu-vdpau-drivers@(|:i386)\
        |xserver-xorg-amdgpu-video-amdgpu\
        |xserver-xorg-hwe-amdgpu-video-amdgpu\
        |vulkan-amdgpu@(|:i386)\
        )
            archpkg=None; comment="unneeded_open_component"
            ;;
         clinfo-amdgpu-pro@(|:i386)\
        |ocl-icd-libopencl1-amdgpu-pro@(|:i386|-dev|-dev:i386)\
        )
            archpkg=None; comment="unneeded_pro_component"
            ;;
         llvm-amdgpu@(|:i386)\
        |llvm-amdgpu-10.0@(|:i386|-dev|-dev:i386|-doc|-runtime|-runtime:i386)\
        |llvm-amdgpu@(-dev|-dev:i386|-runtime|-runtime:i386)\
        |libdrm-amdgpu-dev@(|:i386)\
        |libdrm-amdgpu-radeon1@(|:i386)\
        |libdrm-amdgpu-utils@(|:i386)\
        |libxatracker-amdgpu-dev@(|:i386)\
        |mesa-amdgpu-common-dev@(|:i386)\
        )
            archpkg=None; comment="not_installed_even_in_ubuntu"
            ;;
        amdgpu-pro-pin|amdgpu-pin)
            archpkg=None; comment="debian_specific_package,_not_needed"
            ;;
        "amdgpu-doc")
            archpkg=None; comment="arch_specific_instructions_will_be_covered_in_archwiki"
            ;;
        amdgpu-core|amdgpu-pro-core)
            archpkg=None; comment="unneeded_meta_package" # because they just put conf file in ld.so.conf.d, which amdgpu-pro-libgl already does
            ;;
         libdrm-amdgpu@(-amdgpu1|-common)\
        |libdrm2-amdgpu\
        )
            #archpkg=libdrm-amdgpu; comment="needed_because_probably_changed_by_amd_and_doesnt_work_with_standard_libdrm" # since 19.30-838629 it seems not true anymore
            archpkg=None; comment="unneeded_open_component"
            ;;
        libdrm-amdgpu@(-amdgpu1:i386)\
        |libdrm2-amdgpu:i386\
        )
            # archpkg=lib32-libdrm-amdgpu; comment="needed_because_probably_changed_by_amd_and_doesnt_work_with_standard_libdrm" # since 19.30-838629 it seems not true anymore
            archpkg=None; comment="unneeded_open_component"
            ;;

         libegl1-amdgpu-pro\
        |libgl1-amdgpu-pro-@(appprofiles|dri|ext-hwe|ext|glx)\
        |libglapi1-amdgpu-pro\
        |libgles2-amdgpu-pro\
        )
            archpkg=amdgpu-pro-libgl; comment="mapped_manually"
            ;;

         libegl1-amdgpu-pro:i386\
        |libgl1-amdgpu-pro-@(dri|ext-hwe|ext|glx):i386\
        |libglapi1-amdgpu-pro:i386\
        |libgles2-amdgpu-pro:i386\
        )
            archpkg=lib32-amdgpu-pro-libgl; comment="mapped_manually"
            ;;
         amdgpu-pro-@(hwe|lib32)|amdgpu-pro\
        )
            archpkg=None; comment="we_have_already_combined_libgl_to_single_package"
            ;;
        # Disabling opencl related packages, as they go to opencl-amd
        amdgpu-pro-rocr-opencl\
        |comgr-amdgpu-pro\
        |comgr-amdgpu-pro-dev\
        |hip-rocr-amdgpu-pro\
        |hsa-runtime-rocr-amdgpu\
        |hsa-runtime-rocr-amdgpu-dev\
        |hsakmt-roct-amdgpu\
        |hsakmt-roct-amdgpu-dev\
        |libllvm-amdgpu-pro-rocm\
        |llvm-amdgpu-pro-rocm\
        |llvm-amdgpu-pro-rocm-dev\
        |opencl-orca-amdgpu-pro-icd\
        |opencl-orca-amdgpu-pro-icd:i386\
        |opencl-rocr-amdgpu-pro\
        |opencl-rocr-amdgpu-pro-dev\
        |rocm-device-libs-amdgpu-pro\
        )
            archpkg=None; comment="opencl_goes_to_opencl-amd"
            ;;
         amf-amdgpu-pro\
        |vulkan-amdgpu-pro\
        )
            archpkg=$line; comment="mapped_manually"
            ;;
         vulkan-amdgpu-pro:i386)
            archpkg=lib32-vulkan-amdgpu-pro; comment="mapped_manually"
            ;;

    esac
    if [[ $archpkg == "None" ]]; then
        str="$str $archpkg, #$comment";
    else
        str="$str '$archpkg', #$comment"
    fi
    echo -e "$str";
#     echo -e "$str" | egrep -v "None|opencl|amf|meta|vulkan|wsa|libdrm|roct|wayland" # debugging
done | column -t | sed 's/^/    /'
rm tmp_deb_metapackages_list.txt
rm tmp_non_hwe_list.txt
rm tmp_all_presented_debian_packages.txt
rm tmp_renamed_deb_32bit_packages.txt
#Then it's needed to carefully check pkgs mapping
echo "}"
