dir=`pwd`
for vm in 1.9.3 ree rbx jruby ; do
  if [ -z "$1" -o "$1" = $vm ] ; then
    echo $vm
    cd ../ext/postgres-pr/utils
    rvm $vm exec ruby extconf.rb
    make clean
    make
    cd $dir
    rvm $vm exec ruby test_speed.rb | tee new_${vm}.txt
  fi
done
