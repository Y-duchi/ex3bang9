from rest_framework import serializers
from .models import UserAddresses, Orders, OrderItem
from furniture.models import NewFurniture, NewFurnitureOptions, NewFurnitureImages

# 배송지 serializer
class UserAddressSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserAddresses
        fields = '__all__'

# 주문 아이템 serializer
class OrderItemSerializer(serializers.ModelSerializer):
    option_id = serializers.CharField(source='option.option_id', read_only=True)
    furniture_name = serializers.SerializerMethodField()
    furniture_brand = serializers.SerializerMethodField()
    furniture_image = serializers.SerializerMethodField()
    color = serializers.CharField(source='option.color', read_only=True)
    size = serializers.CharField(source='option.size', read_only=True)
    price = serializers.IntegerField(source='option.price', read_only=True)

    class Meta:
        model = OrderItem
        fields = [
            'option_id',
            'furniture_name',
            'furniture_brand',
            'furniture_image',
            'color',
            'size',
            'quantity',
            'price'
        ]

    def get_furniture_name(self, obj):
        return obj.option.product_id.name if obj.option and obj.option.product_id else None

    def get_furniture_brand(self, obj):
        return obj.option.product_id.brand if obj.option and obj.option.product_id else None

    def get_furniture_image(self, obj):
        if obj.option and obj.option.product_id:
            image = NewFurnitureImages.objects.filter(
                product_id=obj.option.product_id,
                type='main'
            ).first()
            return image.image_url if image else None
        return None

# 주문 목록 serializer
class OrderListSerializer(serializers.ModelSerializer):
    items = serializers.SerializerMethodField()
    order_date = serializers.DateTimeField(format='%Y.%m.%d')

    class Meta:
        model = Orders
        fields = ['order_id', 'total_price', 'order_status', 'order_date', 'items']

    def get_items(self, obj):
        items = OrderItem.objects.filter(order=obj)
        return OrderItemSerializer(items, many=True).data