import 'package:settpay/screens/account/createAccountEntryPage.dart';
import 'package:settpay/service/index.dart';
import 'package:settpay/utils/i18n/index.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:settpay_sdk/plugin/index.dart';
import 'package:settpay_sdk/utils/i18n.dart';
import 'package:settpay_sdk/storage/types/keyPairData.dart';
import 'package:settpay_ui/components/addressIcon.dart';
import 'package:settpay_ui/components/roundedCard.dart';
import 'package:settpay_ui/utils/format.dart';
import 'package:settpay_ui/utils/i18n.dart';
import 'package:settpay_ui/utils/index.dart';

class NetworkSelectPage extends StatefulWidget {
  NetworkSelectPage(this.service, this.plugins, this.changeNetwork);

  static final String route = '/network';

  final AppService service;
  final List<PolkawalletPlugin> plugins;
  final Future<void> Function(PolkawalletPlugin) changeNetwork;

  @override
  _NetworkSelectPageState createState() => _NetworkSelectPageState();
}

class _NetworkSelectPageState extends State<NetworkSelectPage> {
  PolkawalletPlugin _selectedNetwork;
  bool _networkChanging = false;

  Future<void> _reloadNetwork() async {
    setState(() {
      _networkChanging = true;
    });
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(
              I18n.of(context).getDic(i18n_full_dic_ui, 'common')['loading']),
          content: Container(height: 64, child: CupertinoActivityIndicator()),
        );
      },
    );
    await widget.changeNetwork(_selectedNetwork);

    if (mounted) {
      Navigator.of(context).pop();
      setState(() {
        _networkChanging = false;
      });
    }
  }

  Future<void> _onSelect(KeyPairData i) async {
    bool isCurrentNetwork =
        _selectedNetwork.basic.name == widget.service.plugin.basic.name;
    if (i.address != widget.service.keyring.current.address ||
        !isCurrentNetwork) {
      /// set current account
      widget.service.keyring.setCurrent(i);

      if (!isCurrentNetwork) {
        /// set new network and reload web view
        await _reloadNetwork();

        _selectedNetwork.changeAccount(i);
      } else {
        widget.service.plugin.changeAccount(i);
      }

      widget.service.store.assets
          .loadCache(i, widget.service.plugin.basic.name);
    }
    Navigator.of(context).pop(_selectedNetwork);
  }

  Future<void> _onCreateAccount() async {
    bool isCurrentNetwork =
        _selectedNetwork.basic.name == widget.service.plugin.basic.name;
    if (!isCurrentNetwork) {
      await _reloadNetwork();
    }
    Navigator.of(context).pushNamed(CreateAccountEntryPage.route);
  }

  List<Widget> _buildAccountList() {
    final dic = I18n.of(context).getDic(i18n_full_dic_app, 'account');
    List<Widget> res = [
      Text(
        _selectedNetwork.basic.name.toUpperCase(),
        style: Theme.of(context).textTheme.headline4,
      ),
      GestureDetector(
        child: RoundedCard(
          margin: EdgeInsets.only(top: 8, bottom: 16),
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                color: Theme.of(context).unselectedWidgetColor,
              ),
              Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text(
                  dic['add'],
                  style: Theme.of(context).textTheme.headline4,
                ),
              )
            ],
          ),
        ),
        onTap: () => _onCreateAccount(),
      ),
    ];

    /// first item is current account
    List<KeyPairData> accounts = [widget.service.keyring.current];

    /// add optional accounts
    accounts.addAll(widget.service.keyring.optionals);

    res.addAll(accounts.map((i) {
      final bool isCurrentNetwork =
          _selectedNetwork.basic.name == widget.service.plugin.basic.name;
      final accInfo = widget.service.keyring.current.indexInfo;
      final addressMap = widget.service.keyring.store
          .pubKeyAddressMap[_selectedNetwork.basic.ss58.toString()];
      final address = addressMap != null
          ? addressMap[i.pubKey]
          : widget.service.keyring.current.address;
      final String accIndex =
          isCurrentNetwork && accInfo != null && accInfo['accountIndex'] != null
              ? '${accInfo['accountIndex']}\n'
              : '';
      final double padding = accIndex.isEmpty ? 0 : 7;
      final isCurrent = isCurrentNetwork &&
          i.address == widget.service.keyring.current.address;
      return RoundedCard(
        border: isCurrent
            ? Border.all(color: Theme.of(context).primaryColorLight)
            : Border.all(color: Theme.of(context).cardColor),
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.only(top: padding, bottom: padding),
        child: ListTile(
          leading: AddressIcon(address, svg: i.icon),
          title: Text(UI.accountName(context, i)),
          subtitle: Text('$accIndex${Fmt.address(address)}', maxLines: 2),
          trailing: isCurrent
              ? Icon(
                  Icons.check_circle,
                  color: Theme.of(context).primaryColor,
                )
              : Container(width: 8),
          onTap: _networkChanging ? null : () => _onSelect(i),
        ),
      );
    }).toList());
    return res;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _selectedNetwork = widget.service.plugin;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final doc = I18n.of(context).getDic(i18n_full_dic_app, 'profile');
    return Scaffold(
      appBar: AppBar(
        title: Text(doc['setting.network']),
        centerTitle: true,
      ),
      body: _selectedNetwork == null
          ? Container()
          : Row(
              children: <Widget>[
                // left side bar
                Stack(
                  children: [
                    Container(
                      width: 56,
                      // color: Theme.of(context).cardColor,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey[100],
                            blurRadius: 24.0,
                            spreadRadius: 0,
                          )
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.plugins.map((i) {
                        final network = i.basic.name;
                        final isCurrent =
                            network == _selectedNetwork.basic.name;
                        return isCurrent
                            ? _NetworkItemActive(icon: i.basic.icon)
                            : Container(
                                margin: EdgeInsets.all(8),
                                child: IconButton(
                                  padding: EdgeInsets.all(8),
                                  icon: isCurrent
                                      ? i.basic.icon
                                      : i.basic.iconDisabled,
                                  onPressed: () {
                                    if (!isCurrent) {
                                      setState(() {
                                        _selectedNetwork = i;
                                      });
                                    }
                                  },
                                ),
                              );
                      }).toList(),
                    )
                  ],
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.all(16),
                    children: _buildAccountList(),
                  ),
                )
              ],
            ),
    );
  }
}

class _NetworkItemActive extends StatelessWidget {
  _NetworkItemActive({this.icon});
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional.centerEnd,
      children: [
        Padding(
          padding: EdgeInsets.only(right: 8),
          child: SvgPicture.asset(
            'assets/images/network_icon_bg.svg',
            color: Colors.grey[100],
            width: 56,
          ),
        ),
        Padding(
          padding: EdgeInsets.only(right: 44),
          child: SvgPicture.asset(
            'assets/images/network_icon_border.svg',
            color: Theme.of(context).primaryColor,
            width: 10,
          ),
        ),
        Container(
          padding: EdgeInsets.all(8),
          child: SizedBox(child: icon, height: 28, width: 28),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(const Radius.circular(24)),
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 12.0,
                spreadRadius: 0,
                offset: Offset(6.0, 1.0),
              )
            ],
          ),
        )
      ],
    );
  }
}
