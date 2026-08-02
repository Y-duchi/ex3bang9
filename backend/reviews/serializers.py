from rest_framework import serializers
from .models import NewFurnitureReview, NewFurnitureReviewImage


#작성
#신규 가구 리뷰 작성용
class NewFurnitureReviewSerializer(serializers.ModelSerializer):
    content = serializers.CharField(max_length=500)

    class Meta:
        model = NewFurnitureReview
        fields = '__all__'

#조회
#신규 가구 리뷰 조회용
class NewFurnitureReviewImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = NewFurnitureReviewImage
        fields = ['image']

class NewFurnitureReviewListSerializer(serializers.ModelSerializer):
    images = NewFurnitureReviewImageSerializer(many=True, read_only=True)

    class Meta:
        model = NewFurnitureReview
        fields = ['new_review_id', 'user', 'option', 'rating', 'content', 'created_at', 'images']
