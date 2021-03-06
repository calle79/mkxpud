function usage {

	echo "Usage: 
 mkxpud <option> [<project codename>] - Image Generator for xPUD

Options:
	all		Execute the whole process of creating a project image
	clean		Removes most generated files
	image		Genreate image from the working directory
	test		Invoke 'QEMU' to test image with bundled kernel 
	help		Display this help

For further informations please refer to README file."
}

function clean {
	sudo rm -rf working/$MKXPUD_CODENAME
}

function setup {

	echo "[mkxpud] Setup Project: $1"
	MKXPUD_CODENAME=$1
	mkdir -p working/$MKXPUD_CODENAME
	mkdir -p deploy/$MKXPUD_CODENAME
	export MKXPUD_CONFIG=config/$MKXPUD_CODENAME.cookbook
	eval export `./tools/parser $MKXPUD_CONFIG config`

	## FIXME: alias cp='cp -rfpL --remove-destination'
	#cp -rfpL --remove-destination skeleton/rootfs/ working/$MKXPUD_CODENAME/rootfs
	# untar rootfs skeleton
	tar zxf skeleton/rootfs.tgz -C working/$MKXPUD_CODENAME/
	export MKXPUD_TARGET=working/$MKXPUD_CODENAME/rootfs

	# copy /dev nodes
	if [ "$MKXPUD_HOST_DEV" == 'true' ]; then
		sudo tar zcf skeleton/archive/dev-host.tgz /dev/*
		sudo tar zxf skeleton/archive/dev-host.tgz -C $MKXPUD_TARGET/
	else 
		sudo tar zxf skeleton/archive/dev.tgz -C $MKXPUD_TARGET/
	fi
	
	# untar default kernel modules if exists
	if [ -e kernel/module/default-module-$MKXPUD_KERNEL.tgz ]; then
		sudo tar zxf kernel/module/default-module-$MKXPUD_KERNEL.tgz -C $MKXPUD_TARGET/
	fi

	echo "[mkxpud] Project Target: $MKXPUD_TARGET"

}

function install {

	echo "    Preparing recipes..."
	for R in `./tools/parser $MKXPUD_CONFIG recipe`; do 
		for P in `./tools/parser package/recipe/$R.recipe package`; do
		PACKAGE="$PACKAGE $P"
		done
	done
	# add OPT packages
	for R in `./tools/parser $MKXPUD_CONFIG opt`; do 
		for P in `./tools/parser package/recipe/$R.recipe package`; do
		PACKAGE="$PACKAGE $P"
		done
	done

	if [ "$MKXPUD_PKGMGR" != 'skip' ]; then
		sudo $MKXPUD_PKGMGR $PACKAGE
	else 
		echo "You need to install following packages according to your cookbook: "
		echo "$PACKAGE"
	fi

}

function strip {

	echo "    Stripping binaries..."
	for R in `./tools/parser $MKXPUD_CONFIG recipe`; do 
		
		# action 
		eval `./tools/parser package/recipe/$R.recipe action`

		for S in binary data config overwrite; do
		
			for A in `./tools/parser package/recipe/$R.recipe $S`; do
	
			case $S in
				binary) 
						##  host
						cp -rfpl --remove-destination $A $MKXPUD_TARGET/$A
						## ldd-helper
						for i in `./tools/ldd-helper $A`; do 
						
						if [ ! -e $MKXPUD_TARGET/usr/lib/`basename $i` ] && [ ! -e $MKXPUD_TARGET/lib/`basename $i` ]; then
							if [ `dirname $i` == '/usr/lib' ]; then 
							cp -rfpL --remove-destination $i $MKXPUD_TARGET/usr/lib ; 
							else cp -rfpL --remove-destination $i $MKXPUD_TARGET/lib ; fi
						fi
						
						done
					;;
				data) 
						## host 
						[ -d $MKXPUD_TARGET/`dirname $A` ] || mkdir -p $MKXPUD_TARGET/`dirname $A` 
						cp -rfpl --remove-destination $A $MKXPUD_TARGET/$A
					;;
				config) 
						## package/config/*
						[ -d $MKXPUD_TARGET/`dirname $A` ] || mkdir -p $MKXPUD_TARGET/`dirname $A` 
						cp -rfp --remove-destination package/config/$A $MKXPUD_TARGET/$A
					;;
				alternative) 
						## package/alternative/$MKXPUD_CODENAME
						[ -d $MKXPUD_TARGET/`dirname $A` ] || mkdir -p $MKXPUD_TARGET/`dirname $A` 
						cp -rfpL --remove-destination package/alternative/$MKXPUD_CODENAME/$A $MKXPUD_TARGET/$A
					;;
				overwrite) 
						## skeleton/overwrite/
						
						# check binary dependency if the overwrite file is an execute
						if [ -x skeleton/overwrite/$A ] && [ ! -d skeleton/overwrite/$A ]; then
						for i in `./tools/ldd-helper skeleton/overwrite/$A`; do 
						if [ ! -e $MKXPUD_TARGET/usr/lib/`basename $i` ] && [ ! -e $MKXPUD_TARGET/lib/`basename $i` ]; then
							if [ `dirname $i` == '/usr/lib' ]; then 
							cp -rfpL --remove-destination $i $MKXPUD_TARGET/usr/lib ; 
							else cp -rfpL --remove-destination $i $MKXPUD_TARGET/lib ; fi
						fi
						done
						fi
						
						[ -d $MKXPUD_TARGET/`dirname $A` ] || mkdir -p $MKXPUD_TARGET/`dirname $A` 
						cp -rfp skeleton/overwrite/$A $MKXPUD_TARGET/$A
					;;
			esac 
			
			done 
		done 
		
	done

}

function opt {

	echo "    Stripping Opt files..."
	for R in `./tools/parser $MKXPUD_CONFIG opt`; do 
		
		# action 
		eval `./tools/parser package/recipe/$R.recipe action`
		
		# create opt directory
		NAME=`./tools/parser package/recipe/$R.recipe name`
		mkdir -p $MKXPUD_TARGET/opt/$NAME

		for S in binary data config overwrite; do
		
			for A in `./tools/parser package/recipe/$R.recipe $S`; do
	
			case $S in
				binary) 
						##  host
						[ -d $MKXPUD_TARGET/opt/$NAME/`dirname $A` ] || mkdir -p $MKXPUD_TARGET/opt/$NAME/`dirname $A`
						cp -rfpl --remove-destination $A $MKXPUD_TARGET/opt/$NAME/$A
						## ldd-helper
						for i in `./tools/ldd-helper $A`; do 
							
							# if not exist in rootfs 
							if [ ! -e $MKXPUD_TARGET/usr/lib/`basename $i` ] && [ ! -e $MKXPUD_TARGET/lib/`basename $i` ]; then
								if [ `dirname $i` == '/usr/lib' ]; then 
								mkdir -p $MKXPUD_TARGET/opt/$NAME/usr/lib;
								cp -rfpL --remove-destination $i $MKXPUD_TARGET/opt/$NAME/usr/lib ; 
								else mkdir -p $MKXPUD_TARGET/opt/$NAME/lib;
								cp -rfpL --remove-destination $i $MKXPUD_TARGET/opt/$NAME/lib ; fi
							fi
							
						done
					;;
				data) 
						## host 
						[ -d $MKXPUD_TARGET/opt/$NAME/`dirname $A` ] || mkdir -p $MKXPUD_TARGET/opt/$NAME/`dirname $A` 
						cp -rfpl --remove-destination $A $MKXPUD_TARGET/opt/$NAME/$A
					;;
				config) 
						## package/config/*
						[ -d $MKXPUD_TARGET/opt/$NAME/`dirname $A` ] || mkdir -p $MKXPUD_TARGET/opt/$NAME/`dirname $A` 
						cp -rfp --remove-destination package/config/$A $MKXPUD_TARGET/opt/$NAME/$A
					;;
				overwrite) 
						## skeleton/overwrite/
						
						# check binary dependency if the overwrite file is an execute
						if [ -x skeleton/overwrite/$A ] && [ ! -d skeleton/overwrite/$A ]; then
						
							if [ ! -e $MKXPUD_TARGET/usr/lib/`basename $i` ] && [ ! -e $MKXPUD_TARGET/lib/`basename $i` ]; then
						
								if [ `dirname $i` == '/usr/lib' ]; then 
								mkdir -p $MKXPUD_TARGET/opt/$NAME/usr/lib;
								cp -rfpL --remove-destination $i $MKXPUD_TARGET/opt/$NAME/usr/lib ; 
								else mkdir -p $MKXPUD_TARGET/opt/$NAME/lib;
								cp -rfpL --remove-destination $i $MKXPUD_TARGET/opt/$NAME/lib ; fi
							
							fi
						fi
						
						[ -d $MKXPUD_TARGET/opt/$NAME/`dirname $A` ] || mkdir -p $MKXPUD_TARGET/opt/$NAME/`dirname $A` 
						cp -rfp skeleton/overwrite/$A $MKXPUD_TARGET/opt/$NAME/$A
					;;
			esac 
			
			done 
		done 
		
	done

}

function kernel {

	echo "[mkxpud] Adding kernel modules"
	
	MKXPUD_CODENAME=$1
	export MKXPUD_CONFIG=config/$MKXPUD_CODENAME.cookbook
	eval export `./tools/parser $MKXPUD_CONFIG config`
	export MKXPUD_TARGET=working/$MKXPUD_CODENAME/rootfs
	
	for MOD in `./tools/parser $MKXPUD_CONFIG module`; do
		for M in `./tools/module-helper $MOD`; do
		
		## FIXME: workaround with different kernel path
		if [ `echo $M | grep "^/"` ]; then
			[ -d $MKXPUD_TARGET/`dirname $M` ] || mkdir -p $MKXPUD_TARGET/`dirname $M` 
			cp -rfpL --remove-destination $M $MKXPUD_TARGET/$M
		else 
			[ -d $MKXPUD_TARGET/$MKXPUD_MOD_PATH/`dirname $M` ] || mkdir -p $MKXPUD_TARGET/$MKXPUD_MOD_PATH/`dirname $M` 
			cp -rfpL --remove-destination $MKXPUD_MOD_PATH/$M $MKXPUD_TARGET/$MKXPUD_MOD_PATH/$M
		fi
		done
	done

	depmod -b $MKXPUD_TARGET $MKXPUD_KERNEL

}

# post 
# FIXME: hook post scripts
function post {

	echo "[mkxpud] Post-install scripts"

	./tools/busybox-helper

	# check dependencies of each files under usr/lib
	for s in `find $MKXPUD_TARGET/usr/lib/*.so.*`; do 
	
		if [ ! -d $s ]; then 
		for i in `./tools/ldd-helper $s`; do 
			if [ ! -e $MKXPUD_TARGET/usr/lib/`basename $i` ] && [ ! -e $MKXPUD_TARGET/lib/`basename $i` ]; then 
			cp -rfpL --remove-destination $i $MKXPUD_TARGET/usr/lib; fi
		done
		fi
	done

	eval `./tools/parser $MKXPUD_CONFIG action`
	
	if [ -e /usr/bin/upx ]; then 
		for o in `./tools/parser $MKXPUD_CONFIG obfuscate`; do
			upx $MKXPUD_TARGET/$o
		done
	fi
}

function image {

	echo "[mkxpud] Generating image..."
	MKXPUD_CODENAME=$1
	export MKXPUD_CONFIG=config/$MKXPUD_CODENAME.cookbook
	eval export `./tools/parser $MKXPUD_CONFIG config`
	export MKXPUD_TARGET=working/$MKXPUD_CODENAME/rootfs
	
	# move opt from rootfs
	for R in `./tools/parser $MKXPUD_CONFIG opt`; do 
		NAME=`./tools/parser package/recipe/$R.recipe name`
		if [ -e $MKXPUD_TARGET/opt/$NAME ];then 
		mv $MKXPUD_TARGET/opt/$NAME working/$MKXPUD_CODENAME/
		fi
		cd working/$MKXPUD_CODENAME/$NAME
			find | cpio -H newc -o | gzip -9 > ../../../deploy/$MKXPUD_CODENAME/$NAME
		cd -
	done
	
	cd $MKXPUD_TARGET
	find | cpio -H newc -o > ../../../deploy/$MKXPUD_CODENAME.cpio
	cd -

	for format in `./tools/parser $MKXPUD_CONFIG image`; do 
	
	case $format in
			gz)
				cat deploy/$MKXPUD_CODENAME.cpio | gzip -9 > deploy/$MKXPUD_CODENAME/core
				du -h deploy/$MKXPUD_CODENAME/core
			;;
			iso)
				cp -r skeleton/boot/iso/ deploy/$MKXPUD_CODENAME/
				cp $MKXPUD_KERNEL_IMAGE deploy/$MKXPUD_CODENAME/iso/boot/bzImage
				cp deploy/$MKXPUD_CODENAME/* deploy/$MKXPUD_CODENAME/iso/boot/
				mkisofs -R -l -V 'xPUD' -input-charset utf-8 -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o deploy/$MKXPUD_CODENAME.iso deploy/$MKXPUD_CODENAME/iso/
				rm -rf deploy/$MKXPUD_CODENAME/iso/
				du -h deploy/$MKXPUD_CODENAME.iso
			;;
			exe)
				cp -r skeleton/boot/exe/ deploy/$MKXPUD_CODENAME/
				cp $MKXPUD_KERNEL_IMAGE deploy/$MKXPUD_CODENAME/exe/bzImage
				cp deploy/$MKXPUD_CODENAME/* deploy/$MKXPUD_CODENAME/exe/
				cd deploy/$MKXPUD_CODENAME/exe/
				makensis xpud-installer.nsi
				cd -
				mv deploy/$MKXPUD_CODENAME/exe/xpud-installer.exe deploy/$MKXPUD_CODENAME.exe
				rm -rf deploy/$MKXPUD_CODENAME/exe/
				du -h deploy/$MKXPUD_CODENAME.exe
			;;
			*)
			echo "$format: not supported format"
			;;
	esac 
	done

}
