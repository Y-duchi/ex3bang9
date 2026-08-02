from rest_framework import serializers
from .models import Inquiry

class InquirySerializer(serializers.ModelSerializer):
    images = serializers.SerializerMethodField()

    def get_images(self, obj):
        return [img.image.url for img in obj.inquiry_images.all()]

    class Meta:
        model = Inquiry
        fields = [
            'inquiry_id',
            'user',
            'title',
            'content',
            'is_private',
            'inquiry_type',
            'option_id',
            'product_id',
            'created_at',
            'images',
        ]