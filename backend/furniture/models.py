from django.db import models
from users.models import Users

# 새 가구 기본 정보 테이블
class NewFurniture(models.Model):
    product_id = models.AutoField(primary_key=True)     # 상품 ID
    name = models.CharField(max_length=100)             # 상품명
    brand = models.CharField(max_length=50)             # 브랜드명
    category = models.CharField(max_length=50)          # 카테고리
    style = models.CharField(max_length=50)             # 스타일
    delivery_fee = models.IntegerField()                # 배송비
    created_at = models.DateTimeField()                 # 등록날짜

    class Meta:
        db_table = 'new_furniture'
        managed = False

# 새 가구 옵션 정보 테이블
class NewFurnitureOptions(models.Model):
    option_id = models.CharField(primary_key=True, max_length=11)      # 옵션 ID
    product_id = models.ForeignKey(NewFurniture, on_delete=models.CASCADE, db_column='product_id') # 상품 ID
    size = models.CharField(max_length=50)              # 사이즈
    color = models.CharField(max_length=50)             # 색상
    price = models.IntegerField()                       # 가격
    stock = models.IntegerField()                       # 재고량
    sold_count = models.IntegerField()                  # 판매수량

    class Meta:
        db_table = 'new_furniture_options'
        managed = False

# 새 가구 이미지 테이블
class NewFurnitureImages(models.Model):
    image_id = models.CharField(primary_key=True, max_length=11)       # 이미지 ID
    product_id = models.ForeignKey(NewFurniture, related_name='images', on_delete=models.CASCADE, db_column='product_id') # 상품 ID
    image_url = models.CharField(max_length=255)        # 이미지 URL
    type = models.CharField(max_length=20)              # main / detail / description

    class Meta:
        db_table = 'new_furniture_images'
        managed = False

# 중고 가구 테이블
class UsedFurniture(models.Model):
    post_id = models.AutoField(primary_key=True)                    # 게시글 ID
    user = models.ForeignKey(Users, on_delete=models.CASCADE)       # 작성자
    title = models.CharField(max_length=50)                         # 제목
    content = models.TextField()                                    # 내용
    price = models.IntegerField()                                   # 가격
    category = models.CharField(max_length=50)                      # 카테고리
    address = models.CharField(max_length=50)                       # 시/동
    detail_address = models.CharField(max_length=50)                # 상세주소
    transaction_type = models.CharField(max_length=10, choices=[('판매', '판매'), ('나눔', '나눔')]) # 거래 방식
    is_direct_trade = models.BooleanField()                         # 직거래 가능 여부
    is_sold = models.BooleanField(default=False)                    # 판매 완료 여부
    created_at = models.DateTimeField(auto_now_add=True)            # 등록 날짜
    latitude = models.FloatField(null=True, blank=True)             # 위도
    longitude = models.FloatField(null=True, blank=True)            # 경도
    views = models.IntegerField(default=0)

    class Meta:
        db_table = 'used_furniture'
        ordering = ['-created_at'] # 등록날짜를 기준으로 내림차순 정렬 (최신 글이 위에 뜨도록)
        managed = False

# 중고 가구 이미지 테이블
class UsedFurnitureImages(models.Model):
    image_id = models.AutoField(primary_key=True)                   # 이미지 ID
    post = models.ForeignKey(UsedFurniture, related_name='images', on_delete=models.CASCADE, db_column='post_id') # 게시글 ID
    image_url = models.CharField(max_length=255)                    # 이미지 URL

    class Meta:
        db_table = 'used_furniture_images'
        managed = False

# 좋아요 테이블
class Favorite(models.Model):
    user = models.ForeignKey('users.Users', on_delete=models.CASCADE)
    content_type = models.CharField(max_length=50)
    furniture_id = models.IntegerField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'favorite'
