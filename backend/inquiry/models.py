from django.db import models

from furniture.models import NewFurnitureOptions
from users.models import Users

#문의 테이블
class Inquiry(models.Model):
    INQUIRY_TYPE_CHOICES = [
        ('배송', '배송'),
        ('상품', '상품'),
        ('재입고', '재입고'),
        ('기타', '기타'),
    ]

    inquiry_id = models.AutoField(primary_key=True)
    user = models.ForeignKey(Users, on_delete=models.CASCADE, db_column='user_id')
    option = models.ForeignKey(NewFurnitureOptions, on_delete=models.CASCADE, db_column='option_id')
    inquiry_type = models.CharField(max_length=50, choices=INQUIRY_TYPE_CHOICES)
    title = models.CharField(max_length=30)
    content = models.TextField(max_length=500)
    is_private = models.BooleanField(default=False)
    is_answered = models.BooleanField(default=False)
    answer = models.TextField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    answered_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'inquiry'
        managed = False


#문의 이미지 테이블
class InquiryImage(models.Model):
    image_id = models.AutoField(primary_key=True)
    inquiry = models.ForeignKey(Inquiry, on_delete=models.CASCADE, related_name='images')
    image = models.ImageField(upload_to='inquiry_images/')

    class Meta:
        db_table = 'inquiry_images'
        managed = False