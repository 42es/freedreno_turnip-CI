#!/bin/bash -e
green='\033[0;32m'
red='\033[0;31m'
nocolor='\033[0m'

deps="meson ninja patchelf unzip curl pip flex bison zip git"
workdir="$(pwd)/turnip_workdir"
packagedir="$workdir/turnip_module"
ndkver="android-ndk-r29"
sdkver="35"
mesasrc="https://github.com/lfdevs/mesa-for-android-container.git"

#array of string => commit/branch;patch args
base_patches=(
  #"vk;merge_requests/38323;"
  #"tu_direct;merge_requests/38960;"
	#"vk_barrier;merge_requests/38956;"
	#"tu_fixds;merge_requests/39236;"
	#"a7xx_gen1_random_stuff;../../patches/a7xx_gen1_random_stuff.patch;"
	#"8g2_ui_glitch;../../patches/8g2_ui_glitch.patch;"
)
experimental_patches=(
	#"copy_raw;merge_requests/35610;"
	#"tu_autotune;merge_requests/37802;"
	#"force_sysmem_no_autotuner;../../patches/force_sysmem_no_autotuner.patch;"
	#"disable_VK_KHR_workgroup_memory_explicit_layout;../../patches/disable_KHR_workgroup_memory_explicit_layout.patch;"
)
failed_patches=()
commit=""
commit_short=""
mesa_version=""
vulkan_version=""
clear

# there are 4 functions here, simply comment to disable.
# you can insert your own function and make a pull request.
run_all(){
	check_deps
	prep

	if (( ${#base_patches[@]} )); then
		prep "patched"
	fi
 
	if (( ${#experimental_patches[@]} )); then
		prep "experimental"
	fi
}

prep () {
	prepare_workdir "$1"
	build_lib_for_android
	port_lib_for_adrenotool "$1"
}

check_deps(){
	echo "Checking system for required Dependencies ..."
	for deps_chk in $deps;
		do
			sleep 0.25
			if command -v "$deps_chk" >/dev/null 2>&1 ; then
				echo -e "$green - $deps_chk found $nocolor"
			else
				echo -e "$red - $deps_chk not found, can't countinue. $nocolor"
				deps_missing=1
			fi;
		done

		if [ "$deps_missing" == "1" ]
			then echo "Please install missing dependencies" && exit 1
		fi

	echo "Installing python Mako dependency (if missing) ..." $'\n'
	pip install mako &> /dev/null
}

prepare_workdir(){
	echo "Creating and entering to work directory ..." $'\n'
	mkdir -p "$workdir" && cd "$_"

	if [ -z "${ANDROID_NDK_LATEST_HOME}" ]; then
		if [ ! -n "$(ls -d android-ndk*)" ]; then
			echo "Downloading android-ndk from google server (~640 MB) ..." $'\n'
			curl https://dl.google.com/android/repository/"$ndkver"-linux.zip --output "$ndkver"-linux.zip &> /dev/null
			###
			echo "Exracting android-ndk to a folder ..." $'\n'
			unzip "$ndkver"-linux.zip  &> /dev/null
		fi
	else	
		echo "Using android ndk from github image"
	fi

	if [ -z "$1" ]; then
		if [ -d mesa-tu8 ]; then
			echo "Removing old mesa-tu8 ..." $'\n'
			rm -rf mesa-tu8
		fi
		
		echo "Cloning mesa-tu8 ..." $'\n'
		git clone --depth=1 "$mesasrc"

		cd mesa-tu8
		commit_short=$(git rev-parse --short HEAD)
		commit=$(git rev-parse HEAD)
		mesa_version=$(cat VERSION | xargs)
		version=$(awk -F'COMPLETE VK_MAKE_API_VERSION(|)' '{print $2}' <<< $(cat include/vulkan/vulkan_core.h) | xargs)
		major=$(echo $version | cut -d "," -f 2 | xargs)
		minor=$(echo $version | cut -d "," -f 3 | xargs)
