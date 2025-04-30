#!/bin/bash

#*****************************************************************************
#
# Build environment - Ubuntu 64-bit Server 24.04.2
#
# sudo apt update
# sudo apt install build-essential clang flex bison g++ gawk \
# gcc-multilib g++-multilib gettext git libncurses-dev libssl-dev \
# python3-setuptools rsync swig unzip zlib1g-dev file wget
#
#*****************************************************************************

feedSetup() {
	echo "let's prepare feed!"  

	rm -rf openwrt
	rm -rf mtk-openwrt-feeds

	git clone --branch openwrt-24.10 https://git.openwrt.org/openwrt/openwrt.git openwrt || true
	#cd openwrt; git checkout 3a481ae21bdc504f7f0325151ee0cb4f25dfd2cd; cd -;		#toolchain: mold: add PKG_NAME to Makefile
	cd openwrt; git checkout 0b392b925fa16c40dccc487753a4412bd054cd63; cd -;               #kernel: fix UDPv6 GSO segmentation with NAT

	git clone  https://git01.mediatek.com/openwrt/feeds/mtk-openwrt-feeds || true
	#cd mtk-openwrt-feeds; git checkout 3a0f22af03943d350d18042eaea1aa0b8136d716; cd -;	#add handshake with wifi when eth send reset done to wifi
	cd mtk-openwrt-feeds; git checkout c53e5bec0fe7daf6e42bb9ab656ba7210e6d4aa0; cd -;	#HEAD @ 72fa6744 [kernel-6.6][mt7987][switch][Add AN8855 gsw driver]

	#feeds modification
	\cp -r my_files/w-feeds.conf.default openwrt/feeds.conf.default

	### wireless-regdb modification - this remove all regdb wireless countries restrictions
	rm -rf openwrt/package/firmware/wireless-regdb/patches/*.*
	rm -rf mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/24.10/files/package/firmware/wireless-regdb/patches/*.*
	\cp -r my_files/500-tx_power.patch mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/24.10/files/package/firmware/wireless-regdb/patches
	\cp -r my_files/regdb.Makefile openwrt/package/firmware/wireless-regdb/Makefile

	### jumbo frames support
	\cp -r my_files/750-mtk-eth-add-jumbo-frame-support-mt7998.patch openwrt/target/linux/mediatek/patches-6.6

	### tx_power patch - by dan pawlik
	\cp -r my_files/99999_tx_power_check_by_dan_pawlik.patch mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/24.10/files/package/kernel/mt76/patches/

	### required & thermal zone 
	\cp -r my_files/1007-wozi-arch-arm64-dts-mt7988a-add-thermal-zone.patch mtk-openwrt-feeds/24.10/patches-base/

	### DTSI modification
	\cp -r my_files/mt7988a-bananapi-bpi-r4.dtsi openwrt/target/linux/mediatek/dts/
	\cp -r my_files/mt7988a.dtsi openwrt/target/linux/mediatek/dts/

	sed -i 's/CONFIG_PACKAGE_perf=y/# CONFIG_PACKAGE_perf is not set/' mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/24.10/defconfig
	sed -i 's/CONFIG_PACKAGE_perf=y/# CONFIG_PACKAGE_perf is not set/' mtk-openwrt-feeds/autobuild/autobuild_5.4_mac80211_release/mt7988_wifi7_mac80211_mlo/.config
	sed -i 's/CONFIG_PACKAGE_perf=y/# CONFIG_PACKAGE_perf is not set/' mtk-openwrt-feeds/autobuild/autobuild_5.4_mac80211_release/mt7986_mac80211/.config

	cd openwrt
	bash ../mtk-openwrt-feeds/autobuild/unified/autobuild.sh filogic-mac80211-mt7988_rfb-mt7996 log_file=make
	
	cd ..
}

feedUpdate() {
	cd openwrt
	
	# Basic config
	\cp -r ../configs/rc1_ext_mm_config .config

	###fanatic addon
	umask 022
	git clone --branch master --single-branch --no-tags --recurse-submodules https://github.com/fantastic-packages/packages.git fantastic_packages
	cd fantastic_packages
	for v in master 22.03 23.05 24.10; do
		git remote set-branches --add origin $v
		git fetch origin $v
		git branch --track $v origin/$v
	done
	# git remote update -p
	git submodule update --init --recursive
	cd ..
	cat <<-EOF >> feeds.conf.default
	src-link fantastic_packages_packages fantastic_packages/feeds/packages
	src-link fantastic_packages_luci fantastic_packages/feeds/luci
	src-link fantastic_packages_special fantastic_packages/feeds/special
	EOF

	###### Then you can add all required additional feeds/packages ######### 

	# qmi modems extension for example
	\cp -r ../my_files/luci-app-3ginfo-lite-main/sms-tool/ feeds/packages/utils/sms-tool
	\cp -r ../my_files/luci-app-3ginfo-lite-main/luci-app-3ginfo-lite/ feeds/luci/applications
	\cp -r ../my_files/luci-app-modemband-main/luci-app-modemband/ feeds/luci/applications
	\cp -r ../my_files/luci-app-modemband-main/modemband/ feeds/packages/net/modemband
	\cp -r ../my_files/luci-app-at-socat/ feeds/luci/applications

	./scripts/feeds update -a
	./scripts/feeds install -a
	
	cd ..
}

menuConfig() {
	echo "let's make config"
	cd openwrt	
	make menuconfig
	
	cd ..
}

buildIt() {
	echo "let's build openWrt"  
	
	cd openwrt
	
	make -j$(nproc)
	cp bin/targets/mediatek/filogic/openwrt-mediatek-filogic-bananapi_bpi-r4-poe-sdcard.img.gz ../openwrt-bananapi_bpi-r4-sdcard_$(date +"%Y_%m_%d_%I_%M_%p").img.gz
	
	cd ..
}

main(){
	echo "Hi There! what should we do!?"
	echo "1) Prepare feeds!?"
	echo "2) openwrt setup!?"
	echo "3) menu Config setup"
	echo "4) Make OpenWrt Great Again"
	echo "5) Refresh all"
	
	read input  
	
	case $input in
	
	1)  
		feedSetup
		;;
	2)  
		feedUpdate
		;;
	3)  
		menuConfig
		;;
	4) 
		buildIt
		;;
	5)
		feedSetup
		feedUpdate
		menuConfig
		;;
	*)  
		echo "wrong number..." 
		;;	
esac		
}
main
exec /bin/bash "$0" "$@"