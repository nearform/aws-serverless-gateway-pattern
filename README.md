## AWS serverless event gateway pattern

### Architecture

![Architecture](./img/archi.png)

### Deploy the solution

```sh
$ terraform init
$ terraform apply
```

### Test

```
api=$(terraform output -json | jq -r .orders_api_gateway_url.value)
echo "Orders Api Gateway - $api"
```

Create a new order.

```
order=$(curl -XPOST "$api"prod/orders -s | jq -r ".body | fromjson")
echo "New Order is \n$order"
```

Check that the order state is shipped.

```
id=$(echo "$order" | jq -r .order_id)
curl -XGET "$api"prod/order/"$id" -s | jq ".body | fromjson | ."
```
