for vm in 1.9.3 ree rbx jruby ; do
  if [ -z "$1" -o "$1" = $vm ] ; then
    echo $vm
    cd ../ext
    rvm $vm exec ruby extconf.rb
    make clean
    make
    cp unpack_single.so ../lib
    cd ../test_speed
    rvm $vm exec ruby test_speed.rb | tee new_${vm}.txt
  fi
done
