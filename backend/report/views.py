from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from django.utils import timezone

from .models import (
    Report,
    ReportLog,
    CommunityReport,
    CommunityReportLog,
    CommentReport,
    CommentReportLog
)
from furniture.models import UsedFurniture
from community.models import Post, Comment
from users.models import Users



@api_view(['POST'])
def create_report_log(request):
    data = request.data

    post_id = data.get('post_id')
    reporter_email = data.get('reporter_email')  # 로그인한 유저
    reason = data.get('reason')
    content = data.get('content')

    if not all([post_id, reporter_email, reason, content]):
        return Response({'detail': '모든 필드가 필요합니다.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        # 1. 게시글 조회 → 작성자 user_id
        post = UsedFurniture.objects.get(post_id=post_id)
        reported_user = Users.objects.get(user_id=post.user.user_id)  # FK 접근
        reported_email = reported_user.email
    except (UsedFurniture.DoesNotExist, Users.DoesNotExist):
        return Response({'error': '신고 대상 유저를 찾을 수 없습니다.'}, status=status.HTTP_404_NOT_FOUND)

    # 2. 신고 로그 기록
    ReportLog.objects.create(
        reported_email=reported_email,
        reporter_email=reporter_email,
        post_id=post_id,
        reason=reason,
        content=content,
        report_date=timezone.now()
    )

    # 3. 신고 집계 테이블 업데이트
    report, _ = Report.objects.get_or_create(email=reported_email)
    report.report_count += 1
    report.save()

    return Response({'message': '신고가 접수되었습니다.'}, status=status.HTTP_201_CREATED)



# 1) 커뮤니티 게시물 신고 API
@api_view(['POST'])
def create_community_report(request):
    data = request.data
    post_id        = data.get('post_id')
    reporter_email = data.get('reporter_email')
    reason         = data.get('reason')
    content        = data.get('content')

    # 필수 필드 검사
    if not all([post_id, reporter_email, reason, content]):
        return Response(
            {'detail': 'post_id, reporter_email, reason, content 모두 필요합니다.'},
            status=status.HTTP_400_BAD_REQUEST
        )

    # 1) 신고 대상 게시글 조회 → 작성자(신고 대상) 이메일 획득
    try:
        post_obj = Post.objects.get(pk=post_id)
    except Post.DoesNotExist:
        return Response({'detail': '신고 대상 게시글을 찾을 수 없습니다.'},
                        status=status.HTTP_404_NOT_FOUND)

    # post_obj.user는 Users 인스턴스(작성자)라고 가정
    reported_user = post_obj.user
    if not reported_user or not hasattr(reported_user, 'email'):
        return Response({'detail': '신고 대상 게시글 작성자 정보를 찾을 수 없습니다.'},
                        status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    reported_email = reported_user.email

    # 2) 신고 로그 저장
    CommunityReportLog.objects.create(
        reported_email = reported_email,
        reporter_email = reporter_email,
        post           = post_obj,
        reason         = reason,
        content        = content,
        report_date    = timezone.now()
    )

    # 3) 신고 집계 테이블 업데이트
    report_obj, created = CommunityReport.objects.get_or_create(email=reported_email)
    report_obj.report_count += 1
    report_obj.save()

    return Response({'message': '커뮤니티 게시물이 신고 접수되었습니다.'},
                    status=status.HTTP_201_CREATED)


# 2) 댓글 신고 API
@api_view(['POST'])
def create_comment_report(request):
    data = request.data
    comment_id     = data.get('comment_id')
    reporter_email = data.get('reporter_email')
    reason         = data.get('reason')
    content        = data.get('content')

    # 필수 필드 검사
    if not all([comment_id, reporter_email, reason, content]):
        return Response(
            {'detail': 'comment_id, reporter_email, reason, content 모두 필요합니다.'},
            status=status.HTTP_400_BAD_REQUEST
        )

    # 1) 신고 대상 댓글 조회 → 작성자(신고 대상) 이메일 획득
    try:
        comment_obj = Comment.objects.get(pk=comment_id)
    except Comment.DoesNotExist:
        return Response({'detail': '신고 대상 댓글을 찾을 수 없습니다.'},
                        status=status.HTTP_404_NOT_FOUND)

    reported_user = comment_obj.user
    if not reported_user or not hasattr(reported_user, 'email'):
        return Response({'detail': '신고 대상 댓글 작성자 정보를 찾을 수 없습니다.'},
                        status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    reported_email = reported_user.email

    # 2) 신고 로그 저장
    CommentReportLog.objects.create(
        reported_email = reported_email,
        reporter_email = reporter_email,
        comment        = comment_obj,
        reason         = reason,
        content        = content,
        report_date    = timezone.now()
    )

    # 3) 신고 집계 테이블 업데이트
    report_obj, created = CommentReport.objects.get_or_create(email=reported_email)
    report_obj.report_count += 1
    report_obj.save()

    return Response({'message': '댓글이 신고 접수되었습니다.'},
                    status=status.HTTP_201_CREATED)
