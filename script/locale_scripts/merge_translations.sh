#!/bin/bash 

move_dir(){ 
  src=$1
  dest=$2 
  if [ -d "$src" ] 
  then 
    echo "moving $1 to $2"
    mv "$1" "$2" 
  fi
}

install_yaml_merge(){
  command -v npm  || echo "NPM not installed. Exiting"
  npm install -g @alexlafroscia/yaml-merge
}

command -v yaml-merge >/dev/null 2>&1 || install_yaml_merge



#if [ ! -f yaml-merge.jar ] 
#then 
#  wget -O yaml-merge.jar https://github.com/hrishikesh-p/yaml-lam-onnu/releases/download/0.1/yaml-lam-onnu-0.1.0-standalone.jar
#fi;

if [ $# -lt 2 ] 
then 
  echo "usage ./merge_translations.sh <dir_with_new_files> <helpkit_locale_dir>"
  exit 1;
fi

source_dir=$2/config/locales
new_dir=$1

move_dir $new_dir/es-ES $new_dir/es
move_dir $new_dir/ja $new_dir/ja-JP
move_dir $new_dir/es-MX $new_dir/es-LA

for lang in `ls $1`
do 
   cp $new_dir/$lang/en.yml new.yaml 
   echo "$source_dir/${lang}.yml"
   cp $source_dir/${lang}.yml old.yaml 
   yaml-merge old.yaml new.yaml | sed -e 's/\\_/ /g' > "${source_dir}/${lang}.yml"
   #java -jar yaml-merge.jar old.yaml new.yaml "${source_dir}/${lang}.yml"
   echo "copied over $lang"
done 

rm old.yaml
rm new.yaml
