from django.http import JsonResponse
from rest_framework.decorators import api_view
from rest_framework.response import Response

from notification.models import Notification

from users.models import Users


#알림 목록 조회 API
@api_view(['GET'])
def get_notification(request):
    user_id = request.GET.get('user_id')
    if not user_id:
        return Response({'error': 'user_id is required'}, status=400)

    try:
        user = Users.objects.get(user_id=user_id)
    except Users.DoesNotExist:
        return Response({'error': '유저 없음'}, status=404)

    only_unread = request.GET.get('only_unread') == 'true'
    notis = Notification.objects.filter(user=user)
    if only_unread:
        notis = notis.filter(is_read=False)

    notis = notis.order_by('-created_at')

    data = [{
        "notifi_id": n.notifi_id,
        "title": n.title,
        "message": n.message,
        "url": n.url,
        "type": n.type,
        "is_read": n.is_read,
        "created_at": n.created_at.strftime('%Y.%m.%d %H:%M'),
    } for n in notis]

    return JsonResponse(data, safe=False)



#안 읽은 알림 조회 API
@api_view(['GET'])
def get_unread_notification_count(request):
    user_id = request.GET.get('user_id')
    if not user_id:
        return Response({"error": "user_id is required"}, status=400)

    try:
        user = Users.objects.get(user_id=user_id)
    except Users.DoesNotExist:
        return Response({"error": "유저를 찾을 수 없습니다."}, status=404)

    count = Notification.objects.filter(user=user, is_read=False).count()
    return Response({"unread_count": count})


#알림 읽음 처리 API
@api_view(['POST'])
def mark_notification_read(request):
    user_id = request.data.get('user_id')
    if not user_id:
        return Response({"error": "user_id required"}, status=400)

    Notification.objects.filter(user__user_id=user_id, is_read=False).update(is_read=True)
    return Response({"message": "전체 읽음 처리 완료"})