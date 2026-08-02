from django.db import transaction
from django.db.models import Avg, Count
from rest_framework.decorators import api_view, parser_classes
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response

from furniture.models import  NewFurnitureOptions
from reviews.models import NewFurnitureReview, NewFurnitureReviewImage
from reviews.serializers import NewFurnitureReviewListSerializer
from users.models import Users

#리뷰 작성
@api_view(['POST'])
def create_new_furniture_review(request):
    data = request.data

    #유저 확인
    try:
        user = Users.objects.get(user_id=data['user_id'])
    except Users.DoesNotExist:
        return Response({'success': False, 'message': '해당 유저가 존재하지 않습니다.'}, status=400)

    #옵션 확인
    try:
        option = NewFurnitureOptions.objects.get(option_id=data['option_id'])
    except NewFurnitureOptions.DoesNotExist:
        return Response({'success': False, 'message': '해당 옵션이 존재하지 않습니다.'}, status=400)

    #이미지 수 제한
    images = request.FILES.getlist('images')
    if len(images) > 10:
        return Response({'success': False, 'message': '이미지는 최대 10장까지 업로드 가능합니다.'}, status=400)

    try:
        with transaction.atomic():
            # 리뷰 저장
            review = NewFurnitureReview.objects.create(
                user=user,
                option=option,
                rating=int(data['rating']),
                content=data['content']
            )

            # 이미지 저장
            for img in images:
                NewFurnitureReviewImage.objects.create(new_review=review, image=img)

            return Response({'success': True, 'message': '리뷰 작성 완료!'}, status=201)

    except Exception as e:
        return Response({'success': False, 'message': f'서버 오류: {str(e)}'}, status=500)


#신규 가구 내 리뷰 조회 API
@api_view(['GET'])
def get_reviews_by_user(request):
    user_id = request.GET.get('user_id')
    if not user_id:
        return Response({'error': 'user_id is required'}, status=400)

    reviews = NewFurnitureReview.objects.filter(user__user_id=user_id).select_related('option__product_id')

    data = []
    for review in reviews:
        image_urls = [img.image.url for img in review.images.all()]
        option = review.option
        product = option.product_id

        data.append({
            'new_review_id': review.new_review_id,
            'user_id': review.user.user_id,
            'option_id': option.option_id,
            'product_id': product.product_id,  #이거 추가!
            'rating': review.rating,
            'content': review.content,
            'created_at': review.created_at.strftime('%Y-%m-%d'),
            'product_name': product.name,
            'product_image_url': product.images.first().image_url if product.images.exists() else None,
            'review_images': image_urls,
            'color': option.color,
            'size': option.size,
        })

    return Response(data)


# 리뷰 전체 가져오기 (제품별) API
@api_view(['GET'])
def get_reviews_by_product(request):
    product_id = request.GET.get('product_id')
    if not product_id:
        return Response({'error': 'product_id is required'}, status=400)

    reviews = NewFurnitureReview.objects.filter(
        option__product_id=product_id
    ).select_related('option__product_id', 'user').order_by('-created_at')

    data = []
    for review in reviews:
        image_urls = [img.image.url for img in review.images.all()]
        option = review.option
        product = option.product_id  # ForeignKey to NewFurniture

        data.append({
            'new_review_id': review.new_review_id,
            'user_id': review.user.user_id,
            'nickname': review.user.nickname,
            'option_id': option.option_id,
            'rating': review.rating,
            'content': review.content,
            'created_at': review.created_at.strftime('%Y-%m-%d'),
            'product_name': product.name,
            'product_image_url': product.images.first().image_url if product.images.exists() else None,
            'review_images': image_urls,
        })

    return Response(data)


#리뷰 개수 API
@api_view(['GET'])
def get_my_review_count(request):
    user_id = request.GET.get('user_id')
    if not user_id:
        return Response({'error': 'user_id is required'}, status=400)

    count = NewFurnitureReview.objects.filter(user__user_id=user_id).count()
    return Response({'count': count})


#리뷰 전체 가져오기 (옵션별) API
@api_view(['GET'])
def get_reviews_by_option(request):
    option_id = request.GET.get('option_id')
    if not option_id:
        return Response({'error': 'option_id is required'}, status=400)

    reviews = NewFurnitureReview.objects.filter(option_id=option_id).order_by('-created_at')
    serializer = NewFurnitureReviewListSerializer(reviews, many=True)
    return Response(serializer.data)


#신규 가구 리뷰 수정 API
@api_view(['PUT'])
def update_new_review(request, review_id):
    data = request.data

    try:
        review = NewFurnitureReview.objects.get(new_review_id=review_id)

        #작성자 확인
        if review.user.user_id != data['user_id']:
            return Response({'success': False, 'message': '작성자만 수정할 수 있습니다.'}, status=403)

        #수정
        review.rating = data['rating']
        review.content = data['content']
        review.save()

        return Response({'success': True, 'message': '리뷰가 수정되었습니다.'}, status=200)

    except NewFurnitureReview.DoesNotExist:
        return Response({'success': False, 'message': '리뷰를 찾을 수 없습니다.'}, status=404)


#신규 가구 리뷰 삭제 API
@api_view(['DELETE'])
def delete_new_review(request, review_id):
    user_id = request.data.get('user_id')

    try:
        review = NewFurnitureReview.objects.get(new_review_id=review_id)

        #작성자 확인
        if review.user.user_id != user_id:
            return Response({'success': False, 'message': '작성자만 삭제할 수 있습니다.'}, status=403)

        #이미지 삭제
        review.images.all().delete()
        review.delete()

        return Response({'success': True, 'message': '리뷰가 삭제되었습니다.'}, status=200)

    except NewFurnitureReview.DoesNotExist:
        return Response({'success': False, 'message': '리뷰를 찾을 수 없습니다.'}, status=404)

#리뷰 개수 API
@api_view(['GET'])
def get_review_count(request):
    product_id = request.GET.get('product_id')
    if not product_id:
        return Response({'error': 'product_id is required'}, status=400)

    count = NewFurnitureReview.objects.filter(option__product_id=product_id).count()
    return Response({'product_id': product_id, 'count': count})


#별점 평균 API
@api_view(['GET'])
def get_average_rating(request):
    product_id = request.GET.get('product_id')
    if not product_id:
        return Response({'error': 'product_id is required'}, status=400)

    stats = NewFurnitureReview.objects.filter(option__product_id=product_id).aggregate(
        average_rating=Avg('rating'),
        review_count=Count('new_review_id')
    )

    average = stats['average_rating'] or 0.0
    count = stats['review_count']

    return Response({
        'product_id': product_id,
        'average_rating': round(average, 1),
        'review_count': count
    })

##리뷰 유무 확인
@api_view(['GET'])
def has_user_reviewed_option(request):
    user_id = request.GET.get('user_id')
    option_id = request.GET.get('option_id')
    if not user_id or not option_id:
        return Response({'error': '필수 값 누락'}, status=400)

    exists = NewFurnitureReview.objects.filter(user__user_id=user_id, option__option_id=option_id).exists()
    return Response({'review_exists': exists})