from django.db import models
from users.models import Users

# class Users(models.Model):
#     user_id = models.CharField(max_length=100, primary_key=True)  # ✅ 외래키용으로 primary_key 지정
#     password_hash = models.CharField(max_length=255)
#     username = models.CharField(max_length=100)
#     nickname = models.CharField(max_length=100)
#     phone = models.CharField(max_length=20)
#     email = models.EmailField()
#     points = models.IntegerField(default=0)
#     certification = models.BooleanField(default=False)
#
#     def __str__(self):
#         return self.nickname
#
#     class Meta:
#         db_table = 'users'     # ✅ 실제 MySQL 테이블명 지정
#         managed = False        # ✅ Django가 이 테이블 마이그레이션 안 하도록 설정


class Post(models.Model):
    title = models.CharField(max_length=200)
    content = models.TextField()
    views = models.IntegerField(default=0)
    likes = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    user = models.ForeignKey(Users, on_delete=models.CASCADE)  # ✅ 외래키 연결

    def __str__(self):
        return self.title


class PostImage(models.Model):
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name='images')
    image = models.ImageField(upload_to='community_images/')

    def __str__(self):
        return f"Image for Post ID {self.post.id}"


class Comment(models.Model):
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name='comments')
    user = models.ForeignKey(Users, on_delete=models.CASCADE)  # ✅ 사용자 정보 연결
    nickname = models.CharField(max_length=50)
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.nickname}: {self.content[:20]}"


class PostLike(models.Model):
    post = models.ForeignKey(Post, on_delete=models.CASCADE)
    user = models.ForeignKey(Users, on_delete=models.CASCADE)

    class Meta:
        unique_together = ('post', 'user')  # 한 사용자가 하나의 게시글에 한 번만 좋아요 가능
        db_table = 'community_postlike'     # 실제 DB 테이블 이름


# ✅ 임시저장 게시글 모델
class PostDraft(models.Model):
    user = models.ForeignKey(Users, on_delete=models.CASCADE, null=True)
    title = models.CharField(max_length=200)
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"(임시글) {self.title}"

    class Meta:
        db_table = 'community_postdraft'


# ✅ 임시저장 이미지 모델 (여러 장 저장 가능)
class PostDraftImage(models.Model):
    draft = models.ForeignKey(PostDraft, on_delete=models.CASCADE, related_name='images')
    image = models.ImageField(upload_to='draft_images/')

    def __str__(self):
        return f"DraftImage for Draft ID {self.draft.id}"