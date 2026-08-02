from rest_framework import serializers
from .models import NewFurnitureOptions, Favorite, UsedFurniture, UsedFurnitureImages

# 새 가구 옵션 정보 serializer
class NewFurnitureOptionsSerializer(serializers.ModelSerializer):
    class Meta:
        model = NewFurnitureOptions
        fields = ['option_id', 'product_id', 'size', 'color', 'price', 'stock', 'sold_count']

# 중고 가구 이미지 serializer
class UsedFurnitureImagesSerializer(serializers.ModelSerializer):
    class Meta:
        model = UsedFurnitureImages
        fields = ['image_url']

# 중고 가구 게시글 serializer
class UsedFurnitureSerializer(serializers.ModelSerializer):
    images = UsedFurnitureImagesSerializer(many=True, read_only=True)
    user_id = serializers.CharField(source='user.user_id', read_only=True)
    nickname = serializers.CharField(source='user.nickname', read_only=True)
    email = serializers.EmailField(source='user.email', read_only=True)



    class Meta:
        model = UsedFurniture
        fields = [
            'post_id', 'user_id', 'title', 'content', 'price', 'category',
            'address', 'detail_address', 'transaction_type', 'is_direct_trade', 'is_sold',
            'created_at', 'images', 'nickname', 'latitude', 'longitude', 'email', 'views'
        ]
class FavoriteSerializer(serializers.ModelSerializer):
    class Meta:
        model = Favorite
        fields = '__all__'