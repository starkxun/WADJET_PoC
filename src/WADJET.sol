 pragma solidity ^0.8.20; // solhint-disable-line


contract WADJET {
    uint256 constant DAY = 1 days;
    uint256 CYCLE = 21 * DAY;
    address public ceoAddress;
    address public marketingAddress;
    address public devAddress;
    address public insuranceWallet;
    address public communityWallet;
    address public supportWallet;
    struct User {
        uint256 investment; //用户累计投入本金
        uint256 deposit;    // 当前参与收益计算的资金基数
        uint256 profit;     // 已累计单尚未处理的收益缓存
        uint256 rate;       // 收益倍率参数
        uint256 reinvestCheckPoint; // 上轮收益结算/复投相关操作得时间点
        uint256 withdrawCheckPoint; // 本轮提取周期起点时间
        uint256 reinvests;      // 记录本周期哪些天完成了 reinvest（用于“连续复投”校验）
        uint256 withdrawal;
        uint256 refIncome;      // 该用户通过下级推荐链获得的累计推荐收益
        uint256[4] refs;        // 四层推荐人数计数数组
        address referrer;       // 该用户绑定的上级推荐人地址
        bool rateSet;           // 一个防重复加速的开关标记(避免 rate 在同一状态下反复加 15)
    }
    mapping(address => User) public users;

    uint256 public totalUsers;
    uint256 public totalInvestment;
    uint256[] public refPercents = [5, 3, 2, 2];

    event buyEvent(address indexed user, uint256 amount, address referrer);
    event sellEvent(address indexed user, uint256 amount);
    event reinvestEvent(address indexed user, uint256 eggs, uint256 miners);
    event newbie(address indexed user, address referrer);

    constructor(
        address _ceoAddress,
        address _marketingAddress,
        address _insuranceWallet,
        address _communityAddress,
        address _supportWallet
    ) {
        ceoAddress = _ceoAddress;
        marketingAddress = _marketingAddress;
        devAddress = msg.sender;
        insuranceWallet = _insuranceWallet;
        communityWallet = _communityAddress;
        supportWallet = _supportWallet;

        //a root user is required to make referral mandatory
        users[msg.sender].investment = 0.2 ether; //root user is required to make referrals madatory
        users[msg.sender].withdrawCheckPoint = block.timestamp;
        users[msg.sender].reinvestCheckPoint = block.timestamp;
    }

    function reinvest() public {
        User storage user = users[msg.sender];
        if (
            user.reinvestCheckPoint <
            user.withdrawCheckPoint +
                CYCLE *
                (daysPassed(user.withdrawCheckPoint, block.timestamp) / 21)
        ) {
            user.reinvests = 0;
        }
        uint passedDays = daysPassed(user.withdrawCheckPoint, block.timestamp) % 21;
        if ((user.reinvests & ((2**(passedDays) - 1))) != (2**(passedDays) - 1)) {
            reset(msg.sender);  
            return;
        }        
        user.reinvests =
            user.reinvests |
            (2**(daysPassed(user.withdrawCheckPoint, block.timestamp) % 21));

        uint256 profit = calculateProfit(msg.sender);
        user.deposit += (user.profit + profit);
        user.profit = 0;
        user.reinvestCheckPoint = block.timestamp;

        if (canWithdraw(msg.sender) && !user.rateSet) {
            user.rate += 15;
            user.rateSet = true;
        } else if (!canWithdraw(msg.sender) && user.rateSet) {
            user.rateSet = false;
        }

        emit reinvestEvent(msg.sender, profit, user.reinvests);
    }

    // daysPassed(from, to) = (to - from) / 1 day [向下取整]
    function canWithdraw(address _user) public view returns (bool) {
        User storage user = users[msg.sender];
        if (
            user.reinvestCheckPoint <
            user.withdrawCheckPoint +
                CYCLE *
                (daysPassed(user.withdrawCheckPoint, block.timestamp) / 21)
        ) {
            return false;
        }
        return (users[_user].reinvests & ((2**20) - 1)) == (2**20) - 1
                && (daysPassed(user.withdrawCheckPoint, block.timestamp) % 21) == 20;
    }

    function withdraw() public {
        User storage user = users[msg.sender];
        uint256 passedDays = daysPassed(user.withdrawCheckPoint, block.timestamp) % 21;
        require(passedDays == 20, "Withdrawal is closed");
        require(canWithdraw(msg.sender), "Non-consecutive reinvest");

        uint256 profit = user.profit + calculateProfit(msg.sender);
        reset(msg.sender);
        uint256 fee = devFee(profit);
        payable(ceoAddress).transfer(fee);
        payable(marketingAddress).transfer(fee);
        payable(devAddress).transfer(fee);
        payable(communityWallet).transfer(fee);
        payable(insuranceWallet).transfer(fee);
        payable(supportWallet).transfer(SafeMath.div(SafeMath.mul(profit, 125), 1000));
        uint256 net = (profit * 85) / 100;
        net = net + user.withdrawal > 8 * user.investment
            ? SafeMath.sub(8 * user.investment, user.withdrawal)
            : net;
        payable(msg.sender).transfer(net);
        user.withdrawal = SafeMath.add(user.withdrawal, net);
        emit sellEvent(msg.sender, profit);
    }

    function reset(address _user) public {
        User storage user = users[_user];
        user.reinvestCheckPoint = block.timestamp;
        user.withdrawCheckPoint = block.timestamp;
        user.reinvests = 0;
        user.rateSet = false;
        user.profit = 0;
        user.rate = 5;
        user.deposit = user.investment;
    }

    // 此处 ref 为推荐人地址
    function deposit(address ref) public payable {
        require(msg.value >= 2 * 10**17, "invalid amount");
        if (users[msg.sender].referrer == address(0)) {
            require(
                ref != msg.sender &&
                    ref != address(0) &&
                    users[ref].investment > 0,
                "invalid referrer"
            );
            users[msg.sender].referrer = ref;
            users[msg.sender].withdrawCheckPoint = block.timestamp;
            users[msg.sender].rate = 5; // 首次 deposit 初始化 rate 为 5
            totalUsers += 1;
            emit newbie(msg.sender, ref);
        }

        uint256 fee = devFee(msg.value);
        payable(ceoAddress).transfer(fee);
        payable(marketingAddress).transfer(fee);
        payable(devAddress).transfer(fee);
        payable(insuranceWallet).transfer(fee);
        payable(communityWallet).transfer(fee);
        users[msg.sender].investment += msg.value;
        users[msg.sender].profit += (users[msg.sender].profit +
            calculateProfit(msg.sender));   // audit: 这里把旧的profit也加了一次(异常)
        users[msg.sender].reinvestCheckPoint = block.timestamp;
        users[msg.sender].deposit += msg.value;
        totalInvestment = SafeMath.add(totalInvestment, msg.value);

        if (users[msg.sender].referrer != address(0)) {
            address upline = users[msg.sender].referrer;
            for (uint256 i = 0; i < 4; i++) {
                if (upline != address(0)) {
                    uint256 profit = (SafeMath.mul(msg.value, refPercents[i]) /
                        100);
                    users[upline].deposit += profit;
                    users[upline].refIncome += profit;
                    users[upline].refs[i]++;
                    upline = users[upline].referrer;
                } else break;
            }
        }

        emit buyEvent(msg.sender, msg.value, ref);
    }

    // q - 这里的计算公式是什么?
    function calculateProfit(address _user) public view returns (uint256) {
        User storage user = users[_user];
        return
            (min(SafeMath.sub(block.timestamp, user.reinvestCheckPoint), DAY) *
                user.rate *
                user.deposit) /
            DAY /
            1000;
    }

    // 计算单份 开发/运营费用 金额
    // deposit 的时候,把 fee 转给 5 个地址(ceo, marketing,dev, insurance, community)
    function devFee(uint256 amount) public pure returns (uint256) {
        return SafeMath.div(SafeMath.mul(amount, 25), 1000);
    }

    function changeCeo(address _adr) public payable {
        require(msg.sender == devAddress, "invalid call");
        ceoAddress = _adr;
    }

    function changeMarketing(address _adr) public payable {
        require(msg.sender == devAddress, "invalid call");
        marketingAddress = _adr;
    }

    function changeInsurance(address _adr) public payable {
        require(msg.sender == devAddress, "invalid call");
        insuranceWallet = _adr;
    }

    function changeCommunity(address _adr) public payable {
        require(msg.sender == devAddress, "invalid call");
        communityWallet = _adr;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getContractData(address adr)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory d = new uint256[](17);
        User storage user = users[adr];

        d[0] = user.investment;
        d[1] = user.profit + calculateProfit(adr);  
        d[2] = user.deposit;
        d[3] = user.rate;
        d[4] = user.refIncome;
        d[5] = user.withdrawal;
        d[6] = user.reinvestCheckPoint;
        d[7] = user.withdrawCheckPoint;
        d[8] = user.reinvests;
        d[9] = canWithdraw(adr) ? 1 : 0;
        d[10] = getBalance();
        d[11] = totalInvestment;
        d[12] = totalUsers;
        d[13] = user.refs[0];
        d[14] = user.refs[1];
        d[15] = user.refs[2];
        d[16] = user.refs[3];

        return d;
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    function daysPassed(uint256 from, uint256 to)
        public
        pure
        returns (uint256)
    {
        return SafeMath.sub(to, from) / DAY;
    }
}

library SafeMath {
    /**
     * @dev Multiplies two numbers, throws on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    /**
     * @dev Integer division of two numbers, truncating the quotient.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    /**
     * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    /**
     * @dev Adds two numbers, throws on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}