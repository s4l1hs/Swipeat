import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SwipeatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SwipeatAppBar({super.key});

  @override
  Size get preferredSize => Size.fromHeight(64.h);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: Color.fromRGBO((theme.colorScheme.surface.r * 255.0).round(), (theme.colorScheme.surface.g * 255.0).round(), (theme.colorScheme.surface.b * 255.0).round(), 0.02),
      elevation: 0,
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avocado circular badge (emoji fallback)
            Container(
              width: 36.w,
              height: 36.w,
              decoration: const BoxDecoration(
                color: Color(0xFF86C166), // avocado-like green
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color.fromRGBO(0,0,0,0.12), blurRadius: 6, offset: Offset(0, 2))],
              ),
            child: Center(child: Text('🥑', style: TextStyle(fontSize: 18.sp))),
          ),
          SizedBox(width: 10.w),
          Text('Swipeat', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 20.sp)),
        ],
      ),
      // keep actions minimal; reserve space for optional profile icon
      actions: [
        Padding(
          padding: EdgeInsets.only(right: 8.w),
            child: CircleAvatar(
            radius: 18.r,
            backgroundColor: Color.fromRGBO((theme.colorScheme.primary.r * 255.0).round(), (theme.colorScheme.primary.g * 255.0).round(), (theme.colorScheme.primary.b * 255.0).round(), 0.12),
            child: Icon(Icons.person, color: theme.colorScheme.primary),
          ),
        )
      ],
    );
  }
}
