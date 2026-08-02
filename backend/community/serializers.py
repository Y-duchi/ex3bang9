from rest_framework import serializers
from .models import Post, Comment, PostLike, PostImage, PostDraft, PostDraftImage
from django.conf import settings

class CommentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Comment
        fields = ['id', 'post', 'user', 'nickname', 'content', 'created_at']

# ✅ 게시글 이미지 시리얼라이저
class PostImageSerializer(serializers.ModelSerializer):
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = PostImage
        fields = ['image_url']

    def get_image_url(self, obj):
        request = self.context.get('request')
        if obj.image and request:
            return request.build_absolute_uri(obj.image.url)
        return None

class PostSerializer(serializers.ModelSerializer):
    user_id = serializers.CharField(source='user.user_id', read_only=True)
    nickname = serializers.CharField(source='user.nickname', read_only=True)
    # ↓ 여기에 프로필 이미지를 추가한다.
    profile_image_url = serializers.SerializerMethodField()
    comments = CommentSerializer(many=True, read_only=True)
    is_liked = serializers.SerializerMethodField()
    images = PostImageSerializer(many=True, read_only=True)

    class Meta:
        model = Post
        fields = [
            'id', 'title', 'content', 'views', 'likes', 'created_at',
            'user_id', 'nickname', 'profile_image_url',  # profile_image_url 추가
            'comments', 'is_liked', 'images'
        ]
        depth = 1

    def get_profile_image_url(self, obj):
        request = self.context.get('request')
        user = obj.user  # Post.user 는 Users 인스턴스
        if user.profile_image and request:
            return request.build_absolute_uri(user.profile_image.url)
        return ''

    def get_is_liked(self, obj):
        request = self.context.get('request')
        if not request:
            return False
        user_id = request.query_params.get('user_id')
        return PostLike.objects.filter(post=obj, user__user_id=user_id).exists()

# ✅ 임시글 이미지 시리얼라이저
class PostDraftImageSerializer(serializers.ModelSerializer):
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = PostDraftImage
        fields = ['image_url']

    def get_image_url(self, obj):
        request = self.context.get('request')
        if obj.image and request:
            return request.build_absolute_uri(obj.image.url)
        return None

# ✅ 임시글 시리얼라이저 (context-aware로 이미지 처리)
class PostDraftSerializer(serializers.ModelSerializer):
    images = serializers.SerializerMethodField()

    class Meta:
        model = PostDraft
        fields = ['id', 'user', 'title', 'content', 'created_at', 'images']

    def get_images(self, obj):
        request = self.context.get('request')
        return [
            {'image_url': request.build_absolute_uri(img.image.url)}
            for img in obj.images.all() if img.image and request
        ]

#내댓글API
class MyCommentSerializer(serializers.ModelSerializer):
    post_id = serializers.IntegerField(source='post.id', read_only=True)
    post_title = serializers.CharField(source='post.title', read_only=True)
    post_date = serializers.DateTimeField(source='post.created_at', read_only=True)
    view_count = serializers.IntegerField(source='post.views', read_only=True)
    comment_count = serializers.SerializerMethodField()
    like_count = serializers.SerializerMethodField()
    post_image_url = serializers.SerializerMethodField()
    post_user_id = serializers.CharField(source='post.user.user_id', read_only=True)
    #userID 가져오기

    class Meta:
        model = Comment
        fields = [
            'post_id', 'id', 'content', 'created_at', 'nickname',
            'post_title', 'post_date', 'view_count',
            'comment_count', 'like_count', 'post_image_url',
            'post_user_id'
        ]

    def get_comment_count(self, obj):
        return Comment.objects.filter(post=obj.post).count()

    def get_like_count(self, obj):
        return PostLike.objects.filter(post=obj.post).count()

    def get_post_image_url(self, obj):
        image = PostImage.objects.filter(post=obj.post).first()
        if image:
            return self.context['request'].build_absolute_uri(image.image.url)
        return ''
