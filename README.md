# ShelfCollectionView

##说明
 用collectionView，实现一个书架功能， 能够对书架上的书籍进行拖动重排、分组等操作。
  
 <font color=#ff0000>这个功能类似于iphone手机界面对 "应用程序图标" 进行拖动重排、分组。</font>
 
 在Library文件夹里，有下面几个类

Class BookShelfMainView: 书架界面

Class BookshelfCollectionViewFlowLayout： 继承自UICollectionViewFlowLayout，使其可以对书架上的书籍进行拖动重排和分组

Class BookShelfGroupMainView: 分组界面

Class BookShelfGroupViewFlowLayout: 分组界面的UICollectionViewFlowLayout，实现分组界面对书籍的拖动重排功能，这里没有复用BookshelfCollectionViewFlowLayout，一是重排功能比较简单，而BookshelfCollectionViewFlowLayout主要功能在分组上，且分组功能建立在拖动的基础上，复用比较麻烦，所以单独为分组界面的collectionView实现了一个重排的功能。且9.0之后，collectionView是自带重排功能的，这里是为了兼容9.0之前的版本才做的。


Categroy UICollectionView+MathIndexPath: 提供了几个计算IndexPath相关的方法

##使用方法
直接拷贝Libary里这个文件夹， 初始化书架界面方法如下：

    
    BookShelfMainView *bookShelfView = [BookShelfMainView loadFromNib];
    bookShelfView.frame = CGRectMake(0, 20, self.view.frame.size.width, self.view.frame.size.height - 20);
    [self.view addSubview:bookShelfView];
    [bookShelfView initWithData:self.itemsArr];
    
传入的itemsArr数据内容，必须是两种类型，一个是普通的Object类型（表示cell是个未分组的普通书籍），一个是NSArray类型（表示这个cell是个分组）. 书架只对数据内容进行顺序或者分组上的调整，数据里的具体内容并不关心。

BookShelfMainView类里，使用了BookCollectionViewCell和BookGroupCollectionViewCell这两个cell，分别表示普通书籍和分组的cell。根据自己的视觉需要，自己实现。

