// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Common
import Shared
import SiteImageView

struct BlockedTrackerItem: Hashable {
    let identifier = UUID()
    let title: String
    let image: UIImage
}

// MARK: BlockedTrackersTableViewController
class BlockedTrackersTableViewController: UIViewController,
                                          Themeable,
                                          UITableViewDelegate {
    private struct UX {
        static let baseCellHeight: CGFloat = 44
        static let baseDistance: CGFloat = 20
        static let bottomDistance: CGFloat = 350
        static let headerDistance: CGFloat = 8
    }

    private lazy var trackersTable: BlockedTrackersTableView = .build { tableView in
        tableView.delegate = self
    }

    // MARK: Navigation View
    private let navigationView: TrackingProtectionHeaderView = .build { header in
        header.accessibilityIdentifier = AccessibilityIdentifiers.EnhancedTrackingProtection.BlockedTrackers.headerView
    }

    private var constraints = [NSLayoutConstraint]()
    var model: BlockedTrackersTableModel
    var notificationCenter: NotificationProtocol
    var themeManager: ThemeManager
    var themeObserver: NSObjectProtocol?
    let windowUUID: WindowUUID

    var currentWindowUUID: UUID? { return windowUUID }

    init(with model: BlockedTrackersTableModel,
         windowUUID: WindowUUID,
         and notificationCenter: NotificationProtocol = NotificationCenter.default,
         themeManager: ThemeManager = AppContainer.shared.resolve()) {
        self.model = model
        self.windowUUID = windowUUID
        self.notificationCenter = notificationCenter
        self.themeManager = themeManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        notificationCenter.removeObserver(self)
    }

    // MARK: View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupDataSource()
        applySnapshot()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateViewDetails()
        listenForThemeChange(view)
        applyTheme()
    }

    // MARK: View Setup
    private func setupView() {
        setupNavigationView()
        setupTableView()
        NSLayoutConstraint.activate(constraints)
    }

    // MARK: Header View Setup
    private func setupNavigationView() {
        view.addSubview(navigationView)
        let navigationViewContraints = [
            navigationView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0),
            navigationView.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -TPMenuUX.UX.horizontalMargin
            ),
            navigationView.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: TPMenuUX.UX.horizontalMargin
            ),
            navigationView.heightAnchor.constraint(
                greaterThanOrEqualToConstant: UX.baseCellHeight
            )
        ]
        constraints.append(contentsOf: navigationViewContraints)
    }

    // MARK: TableView Setup
    private func setupTableView() {
        view.addSubview(trackersTable)
        let tableConstraints = [
            trackersTable.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: TPMenuUX.UX.horizontalMargin
            ),
            trackersTable.topAnchor.constraint(
                equalTo: navigationView.bottomAnchor,
                constant: UX.headerDistance
            ),
            trackersTable.bottomAnchor.constraint(
                greaterThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: 0
            ),
            trackersTable.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -TPMenuUX.UX.horizontalMargin
            )
        ]
        constraints.append(contentsOf: tableConstraints)
    }

    private func setupDataSource() {
        trackersTable.diffableDataSource =
        UITableViewDiffableDataSource<Int, BlockedTrackerItem>(tableView: trackersTable) { (tableView, indexPath, item)
            -> UITableViewCell? in
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: BlockedTrackerCell.cellIdentifier,
                for: indexPath
            ) as? BlockedTrackerCell else { return UITableViewCell() }

            let isLastItem = indexPath.row == (self.model.getItems().count - 1)
            cell.configure(with: item, hideDivider: isLastItem)
            cell.applyTheme(theme: self.currentTheme())
            return cell
        }
    }

    private func applySnapshot() {
        let items = model.getItems()
        trackersTable.applySnapshot(with: items)
    }

    private func updateViewDetails() {
        navigationView.setTitle(with: model.topLevelDomain)

        if let headerView = trackersTable.headerView(forSection: 0) as? BlockedTrackersHeaderView {
            headerView.totalTrackersBlockedLabel.text = model.getTotalTrackersText()
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 {
            guard let headerView = tableView.dequeueReusableHeaderFooterView(
                withIdentifier: BlockedTrackersHeaderView.cellIdentifier
            ) as? BlockedTrackersHeaderView else { return UIView() }

            headerView.totalTrackersBlockedLabel.text = model.getTotalTrackersText()
            headerView.applyTheme(theme: currentTheme())
            return headerView
        }
        return nil
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    @objc
    func closeButtonTapped() {
        self.dismiss(animated: true)
    }

    // MARK: Notifications
    func handleNotifications(_ notification: Notification) {
        switch notification.name {
        case .DynamicFontChanged:
            adjustLayout()
        default: break
        }
    }

    // MARK: View Transitions
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        adjustLayout()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.adjustLayout()
        }, completion: nil)
    }

    func adjustLayout() {
        for cell in trackersTable.visibleCells {
            if let blockedTrackerCell = cell as? BlockedTrackerCell {
                blockedTrackerCell.invalidateIntrinsicContentSize()
                blockedTrackerCell.setNeedsLayout()
            }
        }
    }

    // MARK: - Themable
    private func currentTheme() -> Theme {
        return themeManager.getCurrentTheme(for: windowUUID)
    }

    func applyTheme() {
        let theme = currentTheme()
        navigationView.applyTheme(theme: theme)
        trackersTable.applyTheme(theme: theme)
        view.backgroundColor = theme.colors.layer1
    }
}
