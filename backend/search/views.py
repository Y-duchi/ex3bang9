from django.db.models import Count, OuterRef, Subquery, IntegerField, Value, Min
from django.db.models.functions import Coalesce
from furniture.models import NewFurniture, NewFurnitureOptions, NewFurnitureImages, Favorite
from django.http import JsonResponse
from django.db.models import Q

def search_furniture(request):
    query = request.GET.get('query', '').strip()
    sort = request.GET.get('sort', '').strip()

    if not query:
        return JsonResponse([], safe=False)

    base_queryset = NewFurniture.objects.filter(
        Q(name__icontains=query) | Q(brand__icontains=query)
    ).distinct()

    price_subquery = NewFurnitureOptions.objects.filter(
        product_id=OuterRef('product_id')
    ).order_by('price').values('price')[:1]

    # 가격 정렬
    if sort == 'price':
        base_queryset = base_queryset.annotate(
            min_price=Coalesce(Subquery(price_subquery, output_field=IntegerField()), 0)
        ).order_by('min_price')

    # 최신순 정렬
    elif sort == 'newest':
        base_queryset = base_queryset.order_by('-product_id')

    # 인기순 정렬 (likes 수 기반)
    elif sort == 'popular':
        # 인기순 정렬을 위해 좋아요 수를 미리 구함
        favorites_count = Favorite.objects.filter(content_type='new') \
            .values('furniture_id') \
            .annotate(like_count=Count('id')) \
            .order_by('-like_count')

        # 가구 id -> 좋아요 수 매핑
        likes_map = {entry['furniture_id']: entry['like_count'] for entry in favorites_count}

        # base_queryset을 순회하면서 좋아요 수 매칭
        result_list = []
        for furniture in base_queryset:
            fid = furniture.product_id
            like_count = likes_map.get(fid, 0)
            price_option = NewFurnitureOptions.objects.filter(product_id=fid).order_by('price').first()
            image = furniture.images.first()

            result_list.append({
                "product_id": fid,
                'brand': furniture.brand,
                'name': furniture.name,
                'price': price_option.price if price_option else 0,
                'image_url': image.image_url if image else None,
                'like_count': like_count,
            })

        # 좋아요 수로 정렬
        result_list.sort(key=lambda x: x['like_count'], reverse=True)
        return JsonResponse(result_list, safe=False)

    # 결과 생성 (가격순/최신순/인기순)
    data = []
    for item in base_queryset:
        price_option = NewFurnitureOptions.objects.filter(product_id=item.product_id).first()
        data.append({
            "product_id": item.product_id,
            'brand': item.brand,
            'name': item.name,
            'price': price_option.price if price_option else 0,
            'image_url': item.images.first().image_url if item.images.exists() else None,
        })

    return JsonResponse(data, safe=False)