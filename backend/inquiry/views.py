from django.http import JsonResponse
from django.utils import timezone
from rest_framework.decorators import api_view
from rest_framework.response import Response

from furniture.models import NewFurnitureOptions
from notification.utils import create_inquiry_answer_notification
from rest_framework.utils import json
from users.models import Users
from .models import Inquiry, InquiryImage


#문의 작성
@api_view(['POST'])
def create_inquiry(request):
    data = request.data
    images = request.FILES.getlist('images')

    if len(images) > 10:
        return Response({'error': '이미지는 최대 10장까지만 업로드 가능합니다.'}, status=400)

    # 필수 항목 확인
    required_fields = ['user_id', 'option_id', 'title', 'content']
    for field in required_fields:
        if field not in data:
            return Response({'error': f'{field}는 필수 입력 항목입니다.'}, status=400)

    try:
        user = Users.objects.get(user_id=data['user_id'])
        option = NewFurnitureOptions.objects.get(option_id=data['option_id'])
    except Users.DoesNotExist:
        return Response({'error': '해당 유저가 존재하지 않습니다.'}, status=404)
    except NewFurnitureOptions.DoesNotExist:
        return Response({'error': '해당 옵션이 존재하지 않습니다.'}, status=404)

    inquiry = Inquiry.objects.create(
        user=user,
        option=option,
        inquiry_type=data.get('inquiry_type', '기타'),
        title=data['title'],
        content=data['content'],
        is_private=data.get('is_private', 'false') == 'true'
    )

    for image in images:
        InquiryImage.objects.create(inquiry=inquiry, image=image)

    return Response({'message': '문의가 등록되었습니다.', 'inquiry_id': inquiry.inquiry_id}, status=201)

#전체 문의 가져오기
@api_view(['GET'])
def get_inquiries_by_product(request):
    product_id = request.GET.get('product_id')
    if not product_id:
        return Response({'error': 'Missing product_id'}, status=400)

    inquiries = Inquiry.objects.filter(option__product_id=product_id).select_related('user', 'option__product_id').order_by('-created_at')

    data = []
    for inquiry in inquiries:
        images = InquiryImage.objects.filter(inquiry=inquiry)
        data.append({
            'inquiry_id': inquiry.inquiry_id,
            'title': inquiry.title,
            'content': inquiry.content,
            'is_answered': inquiry.is_answered,
            'answer': inquiry.answer,
            'created_at': inquiry.created_at.strftime('%Y-%m-%d %H:%M'),
            'nickname': inquiry.user.nickname if inquiry.user and inquiry.user.nickname else '알 수 없음',
            'is_private': inquiry.is_private,
            'option': f"{inquiry.option.color} / {inquiry.option.size}",

            ###여기수정
            'images': [request.build_absolute_uri(img.image.url) for img in inquiry.images.all()],
        })

    return Response(data, status=200)


#내 문의 목록 조회
@api_view(['GET'])
def get_inquiries(request):
    user_id = request.GET.get('user_id')
    try:
        user = Users.objects.get(user_id=user_id)
    except Users.DoesNotExist:
        return Response({'error': '유저를 찾을 수 없습니다.'}, status=404)

    inquiries = Inquiry.objects.filter(user=user).order_by('-created_at')
    result = []

    for inquiry in inquiries:
        option = inquiry.option
        product = option.product_id
        images = InquiryImage.objects.filter(inquiry=inquiry)
        ###여기 수정
        product_image_url = (
            request.build_absolute_uri(product.images.first().image_url)
            if product.images.exists() else None
        )


        result.append({
            'inquiry_id': inquiry.inquiry_id,
            'title': inquiry.title,
            'created_at': inquiry.created_at.strftime('%Y.%m.%d'),
            'is_private': inquiry.is_private,
            'is_answered': inquiry.is_answered,
            'product_image_url': product_image_url,
            'product_id': product.pk,
            'product_name': product.name,
            'brand': product.brand,
            'option': f"{option.color} / {option.size}",
            ###여기 수정
            'images': [img.image.url for img in inquiry.images.all()],
            'content': inquiry.content,
            'inquiry_type': inquiry.inquiry_type,
        })

    return Response({'inquiries': result}, status=200)

#문의 상세(개별) API
@api_view(['GET'])
def get_inquiry_detail(request, inquiry_id):
    try:
        inquiry = Inquiry.objects.get(inquiry_id=inquiry_id)
    except Inquiry.DoesNotExist:
        return Response({'error': '해당 문의를 찾을 수 없습니다.'}, status=404)

    option = inquiry.option
    product = option.product_id
    images = InquiryImage.objects.filter(inquiry=inquiry)

    result = {
        'inquiry_id': inquiry.inquiry_id,
        'user_id': inquiry.user.user_id,
        'title': inquiry.title,
        'content': inquiry.content,
        'inquiry_type': inquiry.inquiry_type,
        'created_at': inquiry.created_at.strftime('%Y.%m.%d %H:%M'),
        'is_private': inquiry.is_private,
        'is_answered': inquiry.is_answered,
        'answer': inquiry.answer,
        'answered_at': inquiry.answered_at.strftime('%Y.%m.%d %H:%M') if inquiry.answered_at else None,
        'product_name': product.name,
        'brand': product.brand,
        'option': f"{option.color} / {option.size}",
        'images': [img.image.url for img in inquiry.images.all()]
    }

    return Response(result, status=200)

#문의 수정
@api_view(['PUT'])
def update_inquiry(request, inquiry_id):
    data = request.data

    try:
        inquiry = Inquiry.objects.get(inquiry_id=inquiry_id)

        # 작성자 확인
        if inquiry.user.user_id != data['user_id']:
            return Response({'success': False, 'message': '작성자만 수정할 수 있습니다.'}, status=403)

        # 답변이 이미 달려 있다면 수정 금지
        if inquiry.is_answered:
            return Response({'success': False, 'message': '답변이 등록된 문의는 수정할 수 없습니다.'}, status=400)

        # 필드 수정
        inquiry.title = data['title']
        inquiry.content = data['content']
        inquiry.inquiry_type = data['inquiry_type']
        inquiry.is_private = data['is_private'] == 'true'
        inquiry.save()

        return Response({'success': True, 'message': '문의가 수정되었습니다.'}, status=200)

    except Inquiry.DoesNotExist:
        return Response({'success': False, 'message': '문의글을 찾을 수 없습니다.'}, status=404)


#문의 삭제
@api_view(['DELETE'])
def delete_inquiry(request, inquiry_id):
    try:
        inquiry = Inquiry.objects.get(inquiry_id=inquiry_id)
    except Inquiry.DoesNotExist:
        return Response({'error': '해당 문의를 찾을 수 없습니다.'}, status=404)

    if inquiry.is_answered:
        return Response({'error': '답변이 달린 문의는 삭제할 수 없습니다.'}, status=400)    #답변 등록 시 삭제 불가

    inquiry.delete()
    return Response({'message': '문의가 삭제되었습니다.'}, status=200)


#답변 작성 및 수정, 알림
@api_view(['PUT'])
def answer_inquiry(request, inquiry_id):
    try:
        inquiry = Inquiry.objects.get(inquiry_id=inquiry_id)
    except Inquiry.DoesNotExist:
        return Response({'error': '해당 문의를 찾을 수 없습니다.'}, status=404)

    data = request.data
    answer_text = data.get('answer', inquiry.answer)

    inquiry.answer = answer_text
    inquiry.is_answered = True
    inquiry.answered_at = timezone.now()
    inquiry.save()

    #답변 등록, 수정 시 알림
    create_inquiry_answer_notification(
        user=inquiry.user,
        inquiry_id=inquiry.inquiry_id,
        product_title=inquiry.option.furniture.title
    )

    return Response({'message': '답변이 등록되었습니다.'}, status=200)