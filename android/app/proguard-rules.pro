# PointGeo - correctif R8 / WorkManager / Room
#
# WorkManager 2.7.0 utilise Room 2.2.5.
# Ces classes sont instanciées par réflexion et leur constructeur
# doit être conservé dans les builds release optimisés.

-keep class androidx.work.impl.WorkDatabase_Impl { <init>(); }
-keep class androidx.work.OverwritingInputMerger { <init>(); }
