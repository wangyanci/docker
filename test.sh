image_id=$(docker images|grep "manage"|grep "\-wyc"|awk -F " " '{print $3}'|uniq)
echo $image_id
[ "$image_id" ]&&docker rmi $image_id
