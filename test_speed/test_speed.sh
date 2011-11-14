for vm in 1.9.3 ree rbx jruby ; do
  echo $vm
  rvm $vm exec ruby test_speed.rb | tee new_${vm}.txt
done
