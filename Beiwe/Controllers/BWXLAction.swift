import XLActionController

/// this cell is used at least in the user menu list of actions
open class BWXLCell: ActionCell {
    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.initialize()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override open func awakeFromNib() {
        super.awakeFromNib()
        self.initialize()
    }
    
    func initialize() {
        // self.backgroundColor = .clearColor() // some old or default value
        self.backgroundColor = AppColors.Beiwe2.withAlphaComponent(0.8)
        let backgroundView = UIView()
        // this alpha compoonent is applied/overlayed when you tap a menu item
        backgroundView.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        self.selectedBackgroundView = backgroundView
        self.actionTitleLabel?.textColor = .white
        self.actionTitleLabel?.textAlignment = .left
    }
}

public struct BWXLHeaderData {
    var title: String
    var subtitle: String
    var image: UIImage
    
    public init(title: String, subtitle: String, image: UIImage) {
        self.title = title
        self.subtitle = subtitle
        self.image = image
    }
}

open class BWXLHeaderView: UICollectionReusableView {
    open lazy var imageView: UIImageView = {
        let imageView = UIImageView(frame: CGRect.zero)
        imageView.image = UIImage(named: "sp-header-icon")
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    open lazy var title: UILabel = {
        let title = UILabel(frame: CGRect.zero)
        title.font = UIFont(name: "HelveticaNeue-Bold", size: 18)
        title.text = "The Fast And ... The Furious Soundtrack Collection"
        title.textColor = UIColor.white
        title.translatesAutoresizingMaskIntoConstraints = false
        title.sizeToFit()
        return title
    }()
    
    open lazy var artist: UILabel = {
        let discArtist = UILabel(frame: CGRect.zero)
        discArtist.font = UIFont(name: "HelveticaNeue", size: 16)
        discArtist.text = "Various..."
        discArtist.textColor = UIColor.white.withAlphaComponent(0.8)
        discArtist.translatesAutoresizingMaskIntoConstraints = false
        discArtist.sizeToFit()
        return discArtist
    }()
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.initialize()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override open func awakeFromNib() {
        super.awakeFromNib()
        self.initialize()
    }
    
    func initialize() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        addSubview(self.imageView)
        addSubview(self.title)
        addSubview(self.artist)
        let separator: UIView = {
            let separator = UIView(frame: CGRect.zero)
            separator.backgroundColor = UIColor.white.withAlphaComponent(0.3)
            separator.translatesAutoresizingMaskIntoConstraints = false
            return separator
        }()
        addSubview(separator)
        
        let views = ["ico": imageView, "title": title, "artist": artist, "separator": separator]
        let metrics = ["icow": 54, "icoh": 54]
        let options = NSLayoutConstraint.FormatOptions()
        
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-15-[ico(icow)]-10-[title]-15-|", options: options, metrics: metrics, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[separator]|", options: options, metrics: metrics, views: views))
        
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-10-[ico(icoh)]", options: options, metrics: metrics, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-18-[title][artist]", options: .alignAllLeft, metrics: metrics, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[separator(1)]|", options: options, metrics: metrics, views: views))
    }
}



/// This Is The User Menu - menu that you open by tapping the user icon after you are registered and logged in
open class BWXLActionController: ActionController<BWXLCell, ActionData, BWXLHeaderView, BWXLHeaderData, UICollectionReusableView, Void> {
    /// runs when view appears, probably is the visual effect for the background of the main page
    fileprivate lazy var blurView: UIVisualEffectView = {
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blurView.autoresizingMask = UIView.AutoresizingMask.flexibleHeight.union(.flexibleWidth) // appears to have no effect...
        return blurView
    }()
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        // backgroundView.addSubview(blurView)
        
        // disabled, this inserts a 20 pixel(?) gap in the menu? what was the ui bug?
        /* Hack.  Why does iOS 11 fail? */
        // if #available(iOS 11.0, *) {
        //     contentHeight = contentHeight + 20
        //     _setUpContentInsetForHeight(view.frame.height)
        // }
        
        self._setUpContentInsetForHeight(view.frame.height)
        self.cancelView?.frame.origin.y = view.bounds.size.height // no obvious effect
        
        // there was a shadow located between the cancel button and the bottom of the list view of options, it wasn't very good.
        // cancelView?.layer.shadowColor = UIColor.black.cgColor
        // cancelView?.layer.shadowOffset = CGSize(width: 0, height: -4)
        // cancelView?.layer.shadowRadius = 2
        // cancelView?.layer.shadowOpacity = 0.6
    }
    
    /// appears to be a fix of some kind for ios 11, or possibly for devices with flush-to-bottom-edge screens
    /// I cannot work out what this code accomplishes.
    fileprivate func _setUpContentInsetForHeight(_ height: CGFloat) {
        let currentInset = collectionView.contentInset
        let bottomInset = settings.cancelView.showCancel ? settings.cancelView.height : currentInset.bottom
        var topInset = height - contentHeight
        if settings.cancelView.showCancel {
            topInset -= settings.cancelView.height
        }
        topInset = max(topInset, max(30, height - contentHeight))
        // no obviouus changes to topInset or bottomInset seem to do anything?
        self.collectionView.contentInset = UIEdgeInsets(top: topInset, left: currentInset.left, bottom: bottomInset, right: currentInset.right)
    }
    
    /// called by os, sets/modifies a blur which I'm pretty sure is disabled...
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.blurView.frame = backgroundView.bounds
    }
    
    override public init(nibName nibNameOrNil: String? = nil, bundle nibBundleOrNil: Bundle? = nil) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        // behaviors for the menu, disabled scrolling so this is probably outdated
        self.settings.behavior.bounces = true
        self.settings.behavior.scrollEnabled = false // scrolling on this is bad, there is no filler, it just moves the elements up. disabling it.
        self.settings.cancelView.showCancel = true
        self.settings.cancelView.hideCollectionViewBehindCancelView = false
        self.settings.cancelView.height = 50
        self.settings.animation.scale = nil // commenting this out makes the menu a bit transparent
        self.settings.animation.present.springVelocity = 0.0
        
        // set the heigh of elements in the menu
        self.cellSpec = .nibFile(nibName: "BWXLCell", bundle: Bundle(for: BWXLCell.self), height: { _ in 60 })
        
        // changing the value has no obvious effect
        self.headerSpec = .cellClass(height: { _ in 84 })
        
        // setup for each of the (4) cells in the menu
        self.onConfigureCellForAction = { [weak self] (cell: BWXLCell, action: Action<ActionData>, indexPath: IndexPath) in
            // assigns assets, image is always nil
            cell.setup(action.data?.title, detail: action.data?.subtitle, image: action.data?.image)
            
            // separator is the line below each cell, this logic disables it for the bottom item (leave study)
            cell.separatorView?.isHidden = indexPath.item == (self?.collectionView.numberOfItems(inSection: indexPath.section))! - 1
            cell.alpha = action.enabled ? 1.0 : 0.5 // always 1.0?
            
            // this... makes the leave study button ~red
            // cell.actionTitleLabel?.textColor = action.style == .destructive ? AppColors.Beiwe5 : UIColor.white
        }
        
        // configures the header... but this code does not appear to execute...
        onConfigureHeader = { (header: BWXLHeaderView, data: BWXLHeaderData) in
            header.title.text = data.title
            header.artist.text = data.subtitle
            header.imageView.image = data.image
        }
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func performCustomDismissingAnimation(_ presentedView: UIView, presentingView: UIView) {
        super.performCustomDismissingAnimation(presentedView, presentingView: presentingView)
        self.cancelView?.frame.origin.y = self.view.bounds.size.height + 10
    }
    
    override open func onWillPresentView() {
        self.cancelView?.frame.origin.y = self.view.bounds.size.height
    }
}
