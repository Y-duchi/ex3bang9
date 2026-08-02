
from django.urls import path
from .views import (
    PostListView, PostDetailView,
    CommentCreateView, CommentListView,
    PostToggleLikeView,
    update_comment, delete_comment,
    drafts_view, delete_draft,  # ✅ 추가
    get_my_comments, get_post_detail
)

urlpatterns = [
    # 게시글 관련 API
    path('posts/', PostListView.as_view(), name='post-list'),
    path('posts/<int:pk>/', PostDetailView.as_view(), name='post-detail'),
    path('posts/<int:pk>/toggle_like/', PostToggleLikeView.as_view(), name='post-toggle-like'),
    path('get_post_detail/', get_post_detail, name='get-post-detail'),

    # 댓글 관련 API
    path('posts/<int:post_id>/comments/', CommentListView.as_view(), name='comment-list'),
    path('comments/create/', CommentCreateView.as_view(), name='comment-create'),
    path('comments/<int:comment_id>/update/', update_comment, name='comment-update'),
    path('comments/<int:comment_id>/delete/', delete_comment, name='comment-delete'),
    path('get_my_comments/', get_my_comments, name='get-my-comments'), ####댓글용이거!!


    # 임시저장 API
    path('drafts/', drafts_view, name='drafts'),                          # ✅ GET + POST (쿼리로 user_id)
    path('drafts/<int:draft_id>/', delete_draft, name='delete-draft'),   # ✅ DELETE
]