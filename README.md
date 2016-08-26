# ShelfCollectionView
 用collectionView，实现一个书架功能， 能够对书架上的书籍进行拖动重排、分组等操作。
  
 <font color=#ff0000>这个功能类似于iphone手机界面对 "应用程序图标" 进行拖动重排、分组。</font>
 

Class BookShelfMainView: 书架界面

Class BookshelfCollectionViewFlowLayout： 继承自UICollectionViewFlowLayout，使其可以对书架上的书籍进行拖动重排和分组

Class BookShelfGroupMainView: 分组界面

Class BookShelfGroupViewFlowLayout: 分组界面的UICollectionViewFlowLayout，实现分组界面对书籍的拖动重排功能，这里没有复用BookshelfCollectionViewFlowLayout，一是重排功能比较简单，而BookshelfCollectionViewFlowLayout主要功能在分组上，且分组功能建立在拖动的基础上，复用比较麻烦，所以单独为分组界面的collectionView实现了一个重排的功能。且9.0之后，collectionView是自带重排功能的，这里是为了兼容9.0之前的版本才做的。