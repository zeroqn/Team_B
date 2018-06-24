pragma solidity 0.4.24;
// pragma experimental "v0.5.0";

import "./SafeMath.sol";


contract Payroll {
    using SafeMath for uint256;

    struct Employee {
        address  addr;
        uint     salary;
        uint     lastPayday;
    }

    uint public constant PAY_DURATION = 30 days;
    uint public constant SALARY_BASE = 1 finney;

    address public owner;
    Employee[] public employeeList;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyEmployee() {
        require(hasEmployee(msg.sender));
        _;
    }

    event OnNewEmployee(address addr, uint salary);
    event OnUpdateEmployee(address oldAddr, address newAddr, uint salary);
    event OnRemoveEmployee(address addr);
    event OnAddFund(uint fund, uint indexed date);
    event OnPay(address employeeAddr, uint amount, uint indexed date);
    event OnWithdraw(uint amount, uint indexed date);

    constructor()
    public
    payable {
        owner = msg.sender;
    }

    function ()
    external
    payable
    {
        revert();
    }

    function addFund()
    external
    payable
    onlyOwner
    returns (uint)
    {
        uint fund = address(this).balance;
        emit OnAddFund(fund, now);

        return fund;
    }

    function getPaid()
    external
    onlyEmployee
    {
        // solhint-disable-next-line indent
        (Employee memory employee, uint idx) = getEmployee(msg.sender);
        employeeList[idx].lastPayday = now;

        uint months = unpaidMonths(employee.lastPayday);
        if (months < 1) {
            revert("Next payday isn't reached");
        }

        pay(employee, months);
    }

    function withdraw(uint amount)
    external
    onlyOwner
    {
        require(amount <= address(this).balance);
        owner.transfer(amount);

        emit OnWithdraw(amount, now);
    }

    function numberOfEmployee()
    external
    view
    returns (uint)
    {
        return employeeList.length;
    }

    function addEmployee(address _addr, uint _salary)
    public
    onlyOwner
    {
        require(_addr != 0x0 && _salary > 0);
        require(!hasEmployee(_addr), "employee address already exist");

        employeeList.push(Employee(_addr, _salary.mul(SALARY_BASE), now));

        emit OnNewEmployee(_addr, _salary);
    }

    function updateEmployee(
        address _addr,
        address _newAddr,
        uint _salary
    )
    public
    onlyOwner
    {
        require(_addr != 0x0 && _newAddr != 0x0 && _salary > 0);

        // solhint-disable-next-line indent
        (Employee memory employee, uint idx) = getEmployee(_addr);
        if (employee.addr == 0x0) {
            revert("Employee not found");
        }

        uint salary = _salary.mul(SALARY_BASE);
        if (employee.salary != salary &&
                now.sub(employee.lastPayday) > PAY_DURATION) {
            revert("Unpaid salary must be paid before setting new salary");
        }

        employeeList[idx].addr = _newAddr;
        employeeList[idx].salary = salary;

        emit OnUpdateEmployee(_addr, _newAddr, _salary);
    }

    function removeEmployee(address _addr)
    public
    onlyOwner
    {
        // solhint-disable-next-line indent
        (Employee memory employee, uint idx) = getEmployee(_addr);
        if (employee.addr == 0x0) {
            revert("Employee not found");
        }

        employeeList[idx] = employeeList[employeeList.length - 1];
        employeeList.length -= 1;

        uint months = unpaidMonths(employee.lastPayday);
        if (months > 0) {
            pay(employee, months);
        }

        emit OnRemoveEmployee(_addr);
    }

    function calculateRunway()
    public
    view
    returns (uint)
    {
        uint totalSalaries = 0;
        for (uint i = 0; i < employeeList.length; i++) {
            totalSalaries = totalSalaries.add(employeeList[i].salary);
        }
        return address(this).balance.div(totalSalaries);
    }

    function hasEnoughFund()
    public
    view
    returns (bool)
    {
        return calculateRunway() > 0;
    }

    /// @notice loop over the whole list of employees
    /// @return Employee the found employee
    /// @return uint     the idx of found employee in array
    function getEmployee(address _addr)
    private
    view
    returns (Employee, uint)
    {
        if (_addr == 0x0) return;

        for (uint i = 0; i < employeeList.length; i++) {
            if (employeeList[i].addr == _addr) {
                return (employeeList[i], i);
            }
        }
    }

    /// @notice loop over the whole list of employees
    function hasEmployee(address _addr)
    private
    view
    returns (bool)
    {
        // solhint-disable-next-line indent
        (Employee memory employee,) = getEmployee(_addr);
        return employee.addr != 0x0;
    }

    function unpaidMonths(uint lastPayday)
    private
    view
    returns (uint)
    {
        return now.sub(lastPayday).div(PAY_DURATION);
    }

    function pay(Employee employee, uint months)
    private
    {
        uint amount = employee.salary.mul(months);

        employee.addr.transfer(amount);

        emit OnPay(employee.addr, amount, now);
    }
}


contract OptimizedPayroll {
    using SafeMath for uint256;

    struct Employee {
        address  addr;
        uint     salary;
        uint     lastPayday;
    }

    uint public constant PAY_DURATION = 30 days;
    uint public constant SALARY_BASE = 1 finney;

    address public owner;
    Employee[] public employeeList;
    uint public totalSalaries;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyEmployee() {
        require(hasEmployee(msg.sender));
        _;
    }

    event OnNewEmployee(address addr, uint salary);
    event OnUpdateEmployee(address oldAddr, address newAddr, uint salary);
    event OnRemoveEmployee(address addr);
    event OnAddFund(uint fund, uint indexed date);
    event OnPay(address employeeAddr, uint amount, uint indexed date);
    event OnWithdraw(uint amount, uint indexed date);

    constructor()
    public
    payable {
        owner = msg.sender;
        totalSalaries = 0;
    }

    function ()
    external
    payable
    {
        revert();
    }

    function addFund()
    external
    payable
    onlyOwner
    returns (uint)
    {
        uint fund = address(this).balance;
        emit OnAddFund(fund, now);

        return fund;
    }

    function getPaid()
    external
    onlyEmployee
    {
        // solhint-disable-next-line indent
        (Employee memory employee, uint idx) = getEmployee(msg.sender);
        employeeList[idx].lastPayday = now;

        uint months = unpaidMonths(employee.lastPayday);
        if (months < 1) {
            revert("Next payday isn't reached");
        }

        pay(employee, months);
    }

    function withdraw(uint amount)
    external
    onlyOwner
    {
        require(amount <= address(this).balance);
        owner.transfer(amount);

        emit OnWithdraw(amount, now);
    }

    function numberOfEmployee()
    external
    view
    returns (uint)
    {
        return employeeList.length;
    }

    function addEmployee(address _addr, uint _salary)
    public
    onlyOwner
    {
        require(_addr != 0x0 && _salary > 0);
        require(!hasEmployee(_addr), "employee address already exist");

        uint salary = _salary.mul(SALARY_BASE);
        employeeList.push(Employee(_addr, salary, now));
        totalSalaries = totalSalaries.add(salary);

        emit OnNewEmployee(_addr, _salary);
    }

    function updateEmployee(
        address _addr,
        address _newAddr,
        uint _salary
    )
    public
    onlyOwner
    {
        require(_addr != 0x0 && _newAddr != 0x0 && _salary > 0);

        // solhint-disable-next-line indent
        (Employee memory employee, uint idx) = getEmployee(_addr);
        if (employee.addr == 0x0) {
            revert("Employee not found");
        }

        uint salary = _salary.mul(SALARY_BASE);
        if (employee.salary != _salary) {
            if (now.sub(employee.lastPayday) > PAY_DURATION) {
                revert("Unpaid salary must be paid before setting new salary");
            }
            totalSalaries = totalSalaries.sub(employee.salary).add(salary);
        }

        employeeList[idx].addr = _newAddr;
        employeeList[idx].salary = salary;

        emit OnUpdateEmployee(_addr, _newAddr, _salary);
    }

    function removeEmployee(address _addr)
    public
    onlyOwner
    {
        // solhint-disable-next-line indent
        (Employee memory employee, uint idx) = getEmployee(_addr);
        if (employee.addr == 0x0) {
            revert("Employee not found");
        }

        totalSalaries = totalSalaries.sub(employee.salary);
        employeeList[idx] = employeeList[employeeList.length - 1];
        employeeList.length -= 1;

        uint months = unpaidMonths(employee.lastPayday);
        if (months > 0) {
            pay(employee, months);
        }

        emit OnRemoveEmployee(_addr);
    }

    function calculateRunway()
    public
    view
    returns (uint)
    {
        return address(this).balance.div(totalSalaries);
    }

    function hasEnoughFund()
    public
    view
    returns (bool)
    {
        return calculateRunway() > 0;
    }

    /// @notice loop over the whole list of employees
    /// @return Employee the found employee
    /// @return uint     the idx of found employee in array
    function getEmployee(address _addr)
    private
    view
    returns (Employee, uint)
    {
        if (_addr == 0x0) return;

        for (uint i = 0; i < employeeList.length; i++) {
            if (employeeList[i].addr == _addr) {
                return (employeeList[i], i);
            }
        }
    }

    /// @notice loop over the whole list of employees
    function hasEmployee(address _addr)
    private
    view
    returns (bool)
    {
        // solhint-disable-next-line indent
        (Employee memory employee,) = getEmployee(_addr);
        return employee.addr != 0x0;
    }

    function unpaidMonths(uint lastPayday)
    private
    view
    returns (uint)
    {
        return now.sub(lastPayday).div(PAY_DURATION);
    }

    function pay(Employee employee, uint months)
    private
    {
        uint amount = employee.salary.mul(months);

        employee.addr.transfer(amount);

        emit OnPay(employee.addr, amount, now);
    }
}
