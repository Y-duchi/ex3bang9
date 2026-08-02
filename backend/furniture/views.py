from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from .models import NewFurniture, NewFurnitureOptions,Favorite, NewFurnitureImages, UsedFurniture, UsedFurnitureImages
from users.models import Users
from .serializers import UsedFurnitureSerializer, NewFurnitureOptionsSerializer
from django.db.models import Min, Sum
from django.core.files.storage import default_storage
from django.db.models import Count
from django.http import JsonResponse

# 가구 목록 불러오기
@api_view(['GET'])
def furniture_list(request):
    furnitures = NewFurniture.objects.all()

    result = []
    for furniture in furnitures:
        # 대표 이미지 가져오기
        main_image = NewFurnitureImages.objects.filter(
            product_id=furniture.product_id, type='main'
        ).first()

        # 최소 가격 가져오기
        min_price = NewFurnitureOptions.objects.filter(
            product_id=furniture.product_id
        ).aggregate(Min('price'))['price__min']

        result.append({
            'furniture_id': furniture.product_id,
            'name': furniture.name,
            'brand': furniture.brand,
            'category': furniture.category,
            'style': furniture.style,
            'min_price': min_price,
            'image_url': main_image.image_url if main_image else None,
            'created_at': furniture.created_at.isoformat(),

        })

    return Response({'furniture': result})


# 가구 상세 정보
@api_view(['GET'])
def furniture_detail(request, product_id):
    try:
        furniture = NewFurniture.objects.get(product_id=product_id)
    except NewFurniture.DoesNotExist:
        return Response({'success': False, 'message': '해당 상품을 찾을 수 없습니다.'}, status=404)

    # 이미지 가져오기
    images = NewFurnitureImages.objects.filter(product_id=furniture.product_id)

    # 이미지 슬라이더
    slider_images = [img.image_url for img in images.filter(type__in=['main', 'detail'])]

    # 상품 정보 이미지
    description_images = [img.image_url for img in images.filter(type='description')]

    # 최소 가격 가져오기
    min_price = NewFurnitureOptions.objects.filter(
        product_id=furniture
    ).aggregate(Min('price'))['price__min']

    data = {
        'furniture_id': furniture.product_id,
        'name': furniture.name,
        'brand': furniture.brand,
        'min_price': min_price,
        'category': furniture.category,
        'style': furniture.style,
        'slider_images': slider_images,
        'description_images': description_images,
        'delivery_fee': furniture.delivery_fee
    }

    return Response({'success': True, 'furniture': data})


# 가구 옵션 조회
@api_view(['GET'])
def get_furniture_options(request, product_id):
    options = NewFurnitureOptions.objects.filter(product_id=product_id)
    serializer = NewFurnitureOptionsSerializer(options, many=True)
    return Response(serializer.data)



# 중고가구 게시글 목록 조회
@api_view(['GET'])
def used_furniture_list(request):
    posts = UsedFurniture.objects.filter(is_sold=False)
    serializer = UsedFurnitureSerializer(posts, many=True)
    return Response(serializer.data)

# 중고가구 판매완료 게시글 목록 조회
@api_view(['GET'])
def sold_furniture_list(request):
    posts = UsedFurniture.objects.filter(is_sold=True)
    serializer = UsedFurnitureSerializer(posts, many=True)
    return Response(serializer.data)


# 중고가구 게시글 작성
@api_view(['POST'])
def create_used_furniture(request):
    data = request.data

    # 유저 ID 객체 조회
    try:
        user = Users.objects.get(user_id=data['user_id'])
    except Users.DoesNotExist:
        return Response({'success': False, 'message': '해당 유저가 존재하지 않습니다.'}, status=400)

    # 직거래 여부 변환
    is_direct_trade = data['is_direct_trade'].lower() == 'true'

    # 게시글 저장
    post = UsedFurniture.objects.create(
        user=user,
        title=data['title'],
        content=data['content'],
        price=0 if data['transaction_type'] == '나눔' else data['price'], # 나눔일 경우 가격 0으로 설정
        category=data['category'],
        address=data['address'],
        detail_address=data['detail_address'],
        transaction_type=data['transaction_type'],
        is_direct_trade=is_direct_trade,
        is_sold=False,
        latitude=data.get('latitude'),
        longitude=data.get('longitude'),
    )

    # 이미지 저장
    images = request.FILES.getlist('images')
    for image in images:
        path = default_storage.save(f'media/used_furniture/{image.name}', image)
        UsedFurnitureImages.objects.create(
            post=post,
            image_url=path
        )

    serializer = UsedFurnitureSerializer(post)
    return Response(serializer.data, status=status.HTTP_201_CREATED)


# 중고거래 상세페이지
@api_view(['GET', 'PUT', 'DELETE'])
def used_furniture_detail(request, post_id):
    try:
        post = UsedFurniture.objects.get(post_id=post_id)
    except UsedFurniture.DoesNotExist:
        return Response({'error': '게시글을 찾을 수 없습니다.'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'GET':
        post.views += 1
        post.save(update_fields=['views'])
        serializer = UsedFurnitureSerializer(post)
        return Response(serializer.data, status=status.HTTP_200_OK)

    elif request.method == 'PUT':
        serializer = UsedFurnitureSerializer(post, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    elif request.method == 'DELETE':
        post.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
# 좋아요
@api_view(['GET', 'POST'])
def toggle_favorite(request):
    if request.method == 'POST':
        user_id = request.data.get('user_id')
        content_type = request.data.get('content_type')
        furniture_id = request.data.get('furniture_id')
        is_favorited = request.data.get('is_favorited', True)

        try:
            user = Users.objects.get(user_id=user_id)

            if is_favorited:
                # 좋아요 추가
                Favorite.objects.get_or_create(
                    user=user,
                    content_type=content_type,
                    furniture_id=furniture_id
                )

                # 중고글에 대한 좋아요면 알림 보내기
                if content_type == 'used':
                    try:
                        product = UsedFurniture.objects.get(post_id=furniture_id)
                        if product.user != user:  # 자기 글 아니면 알림
                            create_like_notification(
                                from_user=user,
                                to_user=product.user,
                                content_type="used",
                                content_id=product.post_id
                            )
                    except UsedFurniture.DoesNotExist:
                        pass

            else:
                # 좋아요 제거
                Favorite.objects.filter(
                    user=user,
                    content_type=content_type,
                    furniture_id=furniture_id
                ).delete()

            return Response({'status': 'success'})

        except Users.DoesNotExist:
            return Response({'status': 'fail', 'message': 'User not found'}, status=404)

    elif request.method == 'GET':
        user_id = request.GET.get('user_id')
        content_type = request.GET.get('content_type')

        favorites = Favorite.objects.filter(user_id=user_id, content_type=content_type)
        results = []

        if content_type == 'new':
            for fav in favorites:
                try:
                    product = NewFurniture.objects.get(product_id=(fav.furniture_id))
                    image = NewFurnitureImages.objects.filter(product_id=product.product_id, type='main').first()
                    option = NewFurnitureOptions.objects.filter(product_id=product.product_id).first()

                    results.append({
                        'product_id': product.product_id,
                        'name': product.name,
                        'brand': product.brand,
                        'price': option.price if option else None,
                        'image_url': image.image_url if image else None,
                    })
                except NewFurniture.DoesNotExist:
                    continue

        elif content_type == 'used':
            for fav in favorites:
                try:
                    product = UsedFurniture.objects.get(post_id=fav.furniture_id)
                    image = UsedFurnitureImages.objects.filter(post_id=product.post_id).first()

                    results.append({
                        'post_id': product.post_id,
                        'title': product.title,
                        'price': product.price,
                        'image_url': image.image_url if image else None,
                    })
                except UsedFurniture.DoesNotExist:
                    continue

        return Response({'favorites': results})




# 인기가구
@api_view(['GET'])
def popular_furniture_list(request):
    # 좋아요 수 기준으로 새 가구 정렬 (내림차순)
    favorites_count = Favorite.objects.filter(content_type='new') \
        .values('furniture_id') \
        .annotate(like_count=Count('id')) \
        .order_by('-like_count')

    furniture_map = {f.product_id: f for f in NewFurniture.objects.all()}
    result = []

    for entry in favorites_count:
        fid = entry['furniture_id']
        count = entry['like_count']
        furniture = furniture_map.get(fid)

        if furniture:
            main_image = NewFurnitureImages.objects.filter(product_id=fid, type='main').first()
            min_price = NewFurnitureOptions.objects.filter(product_id=fid).aggregate(Min('price'))['price__min']

            result.append({
                'furniture_id': fid,
                'name': furniture.name,
                'brand': furniture.brand,
                'category': furniture.category,
                'style': furniture.style,
                'min_price': min_price,
                'image_url': main_image.image_url if main_image else None,
                'like_count': count
            })

    return Response({'furniture': result})


# 유행가구
@api_view(['GET'])
def trendy_furniture_list(request):
    # product_id 기준으로 sold_count 합산 후 내림차순 정렬
    sold_counts = NewFurnitureOptions.objects.values('product_id') \
        .annotate(total_sold=Sum('sold_count')) \
        .order_by('-total_sold')

    furniture_map = {f.product_id: f for f in NewFurniture.objects.all()}
    result = []

    for entry in sold_counts:
        product_id = entry['product_id']
        total_sold = entry['total_sold']
        furniture = furniture_map.get(product_id)

        if not furniture:
            continue

        main_image = NewFurnitureImages.objects.filter(product_id=product_id, type='main').first()
        min_price = NewFurnitureOptions.objects.filter(product_id=product_id).aggregate(Min('price'))['price__min']

        result.append({
            'furniture_id': product_id,
            'name': furniture.name,
            'brand': furniture.brand,
            'category': furniture.category,
            'style': furniture.style,
            'min_price': min_price,
            'image_url': main_image.image_url if main_image else None,
            'sold_count': total_sold
        })

    return Response({'furniture': result})



# 좋아요 개수 가져오기
@api_view(['GET'])
def get_favorite_count(request):
    furniture_id = request.GET.get('furniture_id')
    content_type = request.GET.get('content_type')  # 'new' 또는 'used'

    if not furniture_id or not content_type:
        return Response({'error': '필수 파라미터 누락'}, status=400)

    count = Favorite.objects.filter(
        furniture_id=furniture_id,
        content_type=content_type
    ).count()

    return Response({'furniture_id': furniture_id, 'like_count': count})


#채팅 중고 거래 정보 가져오기
@api_view(['GET'])
def get_used_furniture_chat_info(request):
    post_id = request.GET.get('post_id')

    try:
        post = UsedFurniture.objects.select_related('user').get(post_id=post_id)
    except UsedFurniture.DoesNotExist:
        return Response({'error': '해당 게시글을 찾을 수 없습니다.'}, status=404)

    image = UsedFurnitureImages.objects.filter(post_id=post_id).first() #이미지 가져오기

    return Response({
        'status': '거래 완료' if post.is_sold else '거래 중',
        'title': post.title,
        'price': '나눔' if post.transaction_type == '나눔' else f"{post.price:,}원",
        'nickname': post.user.nickname,
        'user_id': post.user.user_id,
        'image_url': image.image_url if image else None,
    }, status=200, content_type='application/json; charset=utf-8')


#옵션 선택 API
@api_view(['GET'])
def get_product_options(request):
    product_id = request.GET.get('product_id')

    if not product_id:
        return Response(
            {'error': 'product_id가 필요합니다.'},
            status=status.HTTP_400_BAD_REQUEST,
            content_type='application/json; charset=utf-8'
        )

    try:
        product = NewFurniture.objects.get(product_id=product_id)
    except NewFurniture.DoesNotExist:
        return Response(
            {'error': '해당 제품을 찾을 수 없습니다.'},
            status=status.HTTP_404_NOT_FOUND,
            content_type='application/json; charset=utf-8'
        )

    options = NewFurnitureOptions.objects.filter(product_id=product)

    data = [
        {
            'option_id': option.option_id,
            'color': option.color,
            'size': option.size,
            'product_id': str(product.product_id),  # ← 안전하게 str 처리도 함께
        }
        for option in options
    ]

    return Response(
        {'options': data},
        status=status.HTTP_200_OK,
        content_type='application/json; charset=utf-8'
    )


# AI 좋아요
def get_favorite_items(request, user_id):
    if request.method == "GET":
        favorites = Favorite.objects.filter(user_id=user_id)
        result = [
            {
                "id": f.id,
                "user_id": f.user_id,
                "content_type": f.content_type,
                "furniture_id": f.furniture_id,
                "created_at": f.created_at.isoformat()
            }
            for f in favorites
        ]
        return JsonResponse(result, safe=False)

# 판매완료 처리
@api_view(['POST'])
def mark_sold(request, post_id):
    try:
        post = UsedFurniture.objects.get(post_id=post_id)
        post.is_sold = 1
        post.save()
        return Response({'message': '판매 완료 처리되었습니다.'})
    except UsedFurniture.DoesNotExist:
        return Response({'error': '게시글을 찾을 수 없습니다.'}, status=404)

# 판매중, 판매완료 개수 구하기
@api_view(['GET'])
def get_user_sale_counts(request):
    user_id = request.GET.get('user_id')
    if not user_id:
        return Response({'error': 'user_id is required.'}, status=400)

    try:
        user = Users.objects.get(user_id=user_id)
    except Users.DoesNotExist:
        return Response({'error': 'User not found.'}, status=404)

    count_onsale = UsedFurniture.objects.filter(user=user, is_sold=False).count()
    count_sold = UsedFurniture.objects.filter(user=user, is_sold=True).count()

    return Response({
        'on_sale': count_onsale,
        'sold': count_sold
    })