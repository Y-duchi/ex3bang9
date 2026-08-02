from django.db import models
from users.models import Users
from furniture.models import NewFurnitureOptions, UsedFurniture

#신규 가구 리뷰 테이블
class NewFurnitureReview(models.Model):
    new_review_id = models.AutoField(primary_key=True)
    user = models.ForeignKey(Users, on_delete=models.CASCADE, db_column='user_id')
    option = models.ForeignKey(NewFurnitureOptions, on_delete=models.CASCADE, db_column='option_id')
    rating = models.IntegerField()
    content = models.TextField(max_length=500)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'new_furniture_review'
        managed = False
        unique_together = ('user', 'option')

#신규 가구 리뷰 사진 테이블
class NewFurnitureReviewImage(models.Model):
    new_review_image_id = models.AutoField(primary_key=True)
    new_review = models.ForeignKey('NewFurnitureReview', on_delete=models.CASCADE, related_name='images')
    image = models.ImageField(upload_to='review/')  #MEDIA_ROOT 기준 경로

    class Meta:
        db_table = 'new_furniture_review_images'
        managed = False


