from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import generics, serializers, status
from rest_framework.decorators import api_view, parser_classes
from rest_framework.parsers import MultiPartParser, FormParser
from .models import Post, Comment, Users, PostLike, PostImage, PostDraft, PostDraftImage
from .serializers import PostSerializer, CommentSerializer, PostDraftSerializer, MyCommentSerializer
from django.conf import settings
from django.shortcuts import get_object_or_404
import os
from notification.utils import create_comment_notification, create_like_notification

class PostListView(generics.ListCreateAPIView):
    queryset = Post.objects.all().order_by('-created_at')
    serializer_class = PostSerializer
    parser_classes = [MultiPartParser, FormParser]

    def perform_create(self, serializer):
        user_id = self.request.data.get('user_id')
        if not user_id:
            raise serializers.ValidationError("user_id는 필수입니다.")
        try:
            user = Users.objects.get(user_id=user_id)
        except Users.DoesNotExist:
            raise serializers.ValidationError("유저가 존재하지 않습니다.")

        images = self.request.FILES.getlist('images')
        post = serializer.save(user=user)

        for image in images:
            PostImage.objects.create(post=post, image=image)

    def get_serializer_context(self):
        return {'request': self.request}

class PostDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Post.objects.all()
    serializer_class = PostSerializer

    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        instance.views += 1
        instance.save(update_fields=['views'])
        serializer = self.get_serializer(instance)
        return Response(serializer.data)

class CommentCreateView(generics.CreateAPIView):
    queryset = Comment.objects.all()
    serializer_class = CommentSerializer

    def create(self, request, *args, **kwargs):
        data = request.data.copy()
        user_id = data.get('user_id')
        post_id = data.get('post')
        content = data.get('content')
        nickname = data.get('nickname')

        if not all([user_id, post_id, content, nickname]):
            return Response({'error': '필수 필드 누락'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            user = Users.objects.get(user_id=user_id)
        except Users.DoesNotExist:
            return Response({'error': '사용자 없음'}, status=status.HTTP_404_NOT_FOUND)

        comment = Comment.objects.create(
            user=user,
            post_id=post_id,
            nickname=nickname,
            content=content,
        )

        ##알림
        post = Post.objects.get(id=post_id)
        create_comment_notification(writer=user, target_user=post.user, content_type='community/post', content_id=post.id)

        return Response(CommentSerializer(comment).data, status=status.HTTP_201_CREATED)

class CommentListView(generics.ListAPIView):
    serializer_class = CommentSerializer

    def get_queryset(self):
        post_id = self.kwargs['post_id']
        return Comment.objects.filter(post_id=post_id)

class PostToggleLikeView(APIView):
    def post(self, request, pk):
        user_id = request.data.get('user_id')
        if not user_id:
            return Response({'error': 'user_id는 필수입니다.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            post = Post.objects.get(pk=pk)
            user = Users.objects.get(user_id=user_id)
        except (Post.DoesNotExist, Users.DoesNotExist):
            return Response({'error': '게시글 또는 사용자 없음'}, status=status.HTTP_404_NOT_FOUND)

        liked = PostLike.objects.filter(post=post, user=user).first()
        if liked:
            liked.delete()
            post.likes = max(post.likes - 1, 0)
            post.save()
            return Response({'likes': post.likes, 'is_liked': False}, status=status.HTTP_200_OK)
        else:
            PostLike.objects.create(post=post, user=user)
            post.likes += 1
            post.save()

            ##알림
            if post.user_id != user.user_id:  # 문자열로 비교
                to_user = Users.objects.get(user_id=post.user_id)
                create_like_notification(
                    from_user=user,
                    to_user=to_user,
                    content_type='community',
                    content_id=post.id
                )

            return Response({'likes': post.likes, 'is_liked': True}, status=status.HTTP_200_OK)

@api_view(['PUT'])
def update_comment(request, comment_id):
    try:
        comment = Comment.objects.get(pk=comment_id)
    except Comment.DoesNotExist:
        return Response({'error': '댓글을 찾을 수 없습니다.'}, status=status.HTTP_404_NOT_FOUND)

    content = request.data.get('content')
    if not content:
        return Response({'error': '댓글 내용은 필수입니다.'}, status=status.HTTP_400_BAD_REQUEST)

    comment.content = content
    comment.save()
    return Response({'message': '댓글이 수정되었습니다.'}, status=status.HTTP_200_OK)

@api_view(['DELETE'])
def delete_comment(request, comment_id):
    try:
        comment = Comment.objects.get(pk=comment_id)
    except Comment.DoesNotExist:
        return Response({'error': '댓글을 찾을 수 없습니다.'}, status=status.HTTP_404_NOT_FOUND)

    comment.delete()
    return Response({'message': '댓글이 삭제되었습니다.'}, status=status.HTTP_204_NO_CONTENT)

# ✅ 임시글 저장 및 조회 (이미지 포함)
@api_view(['GET', 'POST'])
@parser_classes([MultiPartParser, FormParser])
def drafts_view(request):
    if request.method == 'POST':
        user_id = request.data.get('user_id')
        title = request.data.get('title')
        content = request.data.get('content')
        images = request.FILES.getlist('images')

        if not all([user_id, title, content]):
            return Response({'error': 'user_id, title, content는 필수입니다.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            user = Users.objects.get(user_id=user_id)
        except Users.DoesNotExist:
            return Response({'error': '사용자 없음'}, status=status.HTTP_404_NOT_FOUND)

        draft = PostDraft.objects.create(user=user, title=title, content=content)

        for image in images:
            PostDraftImage.objects.create(draft=draft, image=image)

        # ✅ context 추가하여 serializer 사용 (POST 응답에서도)
        serializer = PostDraftSerializer(draft, context={'request': request})
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    elif request.method == 'GET':
        user_id = request.query_params.get('user_id')
        if not user_id:
            return Response({'error': 'user_id가 필요합니다.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            user = Users.objects.get(user_id=user_id)
        except Users.DoesNotExist:
            return Response({'error': '사용자 없음'}, status=status.HTTP_404_NOT_FOUND)

        drafts = PostDraft.objects.filter(user=user).order_by('-created_at')
        serializer = PostDraftSerializer(drafts, many=True, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)

# ✅ 임시글 삭제
@api_view(['DELETE'])
def delete_draft(request, draft_id):
    draft = get_object_or_404(PostDraft, id=draft_id)
    draft.delete()
    return Response({'message': '임시글이 삭제되었습니다.'}, status=status.HTTP_204_NO_CONTENT)

#내가 작성한 댓글 API
@api_view(['GET'])
def get_my_comments(request):
    user_id = request.GET.get('user_id')
    if not user_id:
        return Response({'error': 'user_id가 필요합니다.'}, status=400)

    try:
        user = Users.objects.get(user_id=user_id)
    except Users.DoesNotExist:
        return Response({'error': '사용자 없음'}, status=404)

    comments = Comment.objects.filter(user=user).order_by('-created_at')
    serializer = MyCommentSerializer(comments, many=True, context={'request': request})
    return Response(serializer.data, status=200)

#d원래 포스트 가져오기
@api_view(['GET'])
def get_post_detail(request):
    post_id = request.GET.get('post_id')
    if not post_id:
        return Response({'error': 'post_id가 필요합니다.'}, status=400)

    post = get_object_or_404(Post, id=post_id)
    serializer = PostSerializer(post, context={'request': request})
    return Response(serializer.data, status=200)

